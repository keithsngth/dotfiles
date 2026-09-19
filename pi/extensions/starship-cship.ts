import { fileURLToPath } from "node:url";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STARSHIP_STATUS = "dotfiles:starship";
const CSHIP_STATUS = "dotfiles:cship";
const CSHIP_CONFIG = fileURLToPath(new URL("./cship-pi.toml", import.meta.url));
const REFRESH_INTERVAL_MS = 300;

type UsageTotals = {
  input: number;
  output: number;
  cacheCreation: number;
  cacheRead: number;
  cost: number;
  latest: {
    input: number;
    output: number;
    cacheCreation: number;
    cacheRead: number;
  };
};

function shellQuote(value: string): string {
  return `'${value.replaceAll("'", "'\\''")}'`;
}

function footerValue(value: string): string {
  return value.replaceAll(/\r?\n/g, "").trim();
}

function usageTotals(ctx: ExtensionContext): UsageTotals {
  const totals: UsageTotals = {
    input: 0,
    output: 0,
    cacheCreation: 0,
    cacheRead: 0,
    cost: 0,
    latest: { input: 0, output: 0, cacheCreation: 0, cacheRead: 0 },
  };

  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type !== "message" || entry.message.role !== "assistant") continue;

    const usage = entry.message.usage;
    totals.input += usage.input;
    totals.output += usage.output;
    totals.cacheCreation += usage.cacheWrite;
    totals.cacheRead += usage.cacheRead;
    totals.cost += usage.cost.total;
    totals.latest = {
      input: usage.input,
      output: usage.output,
      cacheCreation: usage.cacheWrite,
      cacheRead: usage.cacheRead,
    };
  }

  return totals;
}

function cshipContext(ctx: ExtensionContext): Record<string, unknown> {
  const model = ctx.model;
  const usage = ctx.getContextUsage();
  const totals = usageTotals(ctx);
  const contextWindow = usage?.contextWindow ?? model?.contextWindow ?? 0;
  const usedPercentage =
    usage?.percent ??
    (usage?.tokens !== null && usage?.tokens !== undefined && contextWindow > 0
      ? (usage.tokens / contextWindow) * 100
      : 0);

  return {
    cwd: ctx.cwd,
    session_id: ctx.sessionManager.getSessionId(),
    transcript_path: ctx.sessionManager.getSessionFile() ?? "",
    model: {
      id: model?.id ?? "pi",
      display_name: model?.name ?? model?.id ?? "Pi",
    },
    effort: { level: ctx.thinkingLevel ?? "off" },
    cost: { total_cost_usd: totals.cost },
    context_window: {
      context_window_size: contextWindow,
      used_percentage: usedPercentage,
      remaining_percentage: Math.max(0, 100 - usedPercentage),
      total_input_tokens: totals.input,
      total_output_tokens: totals.output,
      current_usage: {
        input_tokens: totals.latest.input,
        output_tokens: totals.latest.output,
        cache_creation_input_tokens: totals.latest.cacheCreation,
        cache_read_input_tokens: totals.latest.cacheRead,
      },
    },
    workspace: {
      current_dir: ctx.cwd,
      project_dir: ctx.cwd,
    },
  };
}

export default function starshipCshipExtension(pi: ExtensionAPI): void {
  let generation = 0;
  let refreshTimer: ReturnType<typeof setTimeout> | undefined;
  let lastRefreshAt = 0;
  let refreshSerial = 0;

  async function refresh(ctx: ExtensionContext): Promise<void> {
    const serial = ++refreshSerial;
    const cshipInput = JSON.stringify(cshipContext(ctx));
    const [starship, cship] = await Promise.all([
      pi.exec("starship", ["prompt", "-p", ctx.cwd], { cwd: ctx.cwd, timeout: 1000 }),
      pi.exec(
        "sh",
        [
          "-c",
          `printf '%s' ${shellQuote(cshipInput)} | cship --config ${shellQuote(CSHIP_CONFIG)}`,
        ],
        { cwd: ctx.cwd, timeout: 1500 },
      ),
    ]);

    if (serial !== refreshSerial) return;
    ctx.ui.setStatus(STARSHIP_STATUS, starship.code === 0 ? footerValue(starship.stdout) : undefined);
    ctx.ui.setStatus(CSHIP_STATUS, cship.code === 0 ? footerValue(cship.stdout) : undefined);
  }

  function schedule(ctx: ExtensionContext): void {
    const now = Date.now();
    if (now - lastRefreshAt >= REFRESH_INTERVAL_MS) {
      lastRefreshAt = now;
      void refresh(ctx).catch(() => undefined);
      return;
    }

    if (refreshTimer) return;
    const scheduledGeneration = generation;
    refreshTimer = setTimeout(() => {
      refreshTimer = undefined;
      if (scheduledGeneration !== generation) return;
      lastRefreshAt = Date.now();
      void refresh(ctx).catch(() => undefined);
    }, REFRESH_INTERVAL_MS - (now - lastRefreshAt));
  }

  pi.on("session_start", (_event, ctx) => {
    generation += 1;
    schedule(ctx);
  });
  pi.on("model_select", (_event, ctx) => schedule(ctx));
  pi.on("thinking_level_select", (_event, ctx) => schedule(ctx));
  pi.on("message_update", (_event, ctx) => schedule(ctx));
  pi.on("turn_end", (_event, ctx) => schedule(ctx));
  pi.on("agent_end", (_event, ctx) => schedule(ctx));
  pi.on("session_shutdown", (_event, ctx) => {
    generation += 1;
    if (refreshTimer) clearTimeout(refreshTimer);
    refreshTimer = undefined;
    ctx.ui.setStatus(STARSHIP_STATUS, undefined);
    ctx.ui.setStatus(CSHIP_STATUS, undefined);
  });
}
