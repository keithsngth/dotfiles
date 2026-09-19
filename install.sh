#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$REPO_DIR/manifest.conf"

log() { printf '==> %s\n' "$1"; }

ensure_herdr() {
  if command -v herdr >/dev/null 2>&1; then
    log "herdr already installed"
    return
  fi
  log "installing herdr..."
  curl -fsSL https://herdr.dev/install.sh | sh
}

ensure_pi() {
  if command -v pi >/dev/null 2>&1; then
    log "pi already installed"
    return
  fi
  if ! command -v npm >/dev/null 2>&1; then
    echo "error: npm not found. Install Node.js first, then re-run this script." >&2
    exit 1
  fi
  log "installing pi..."
  npm install -g @earendil-works/pi-coding-agent
}

link_manifest() {
  while IFS='|' read -r src target; do
    [ -z "$src" ] && continue
    case "$src" in \#*) continue ;; esac

    target="${target/#\~/$HOME}"
    src_abs="$REPO_DIR/$src"
    mkdir -p "$(dirname "$target")"

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$src_abs" ]; then
      log "up to date: $target"
      continue
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
      backup="$target.bak.$(date +%Y%m%d%H%M%S)"
      log "backing up existing $target -> $backup"
      mv "$target" "$backup"
    fi

    ln -s "$src_abs" "$target"
    log "linked $target -> $src_abs"
  done < "$MANIFEST"
}

ensure_herdr
ensure_pi
link_manifest

log "done."
