-- Minimal tab bar and status line.
--
-- Deliberately flat: no filled powerline segments, no separate chrome strip.
-- Claude Code's cship status line already sits inside the terminal as plain
-- accented text, so a second bar in solid colour blocks competes with it. Here
-- the bar background matches the window background, which lets the window's
-- transparency and blur carry straight through it, and colour is spent only on
-- small icons -- text stays muted.

local wezterm = require("wezterm")

local M = {}

local ICON_WORKSPACE = utf8.char(0xf009) -- 
local ICON_FOLDER = utf8.char(0xf07c) -- 
local ICON_CLOCK = utf8.char(0xf017) -- 
local ICON_UNSEEN = utf8.char(0xf444) -- 
local DIVIDER = utf8.char(0x2502) -- │
local ACTIVE_MARK = utf8.char(0x258e) -- ▎

-- Glyph per foreground process. Literal codepoints rather than
-- wezterm.nerdfonts lookups, so a renamed key upstream can't break the bar.
local PROCESS_ICONS = {
	bash = utf8.char(0xf489),
	zsh = utf8.char(0xf489),
	fish = utf8.char(0xf489),
	nvim = utf8.char(0xe62b),
	vim = utf8.char(0xe62b),
	git = utf8.char(0xe702),
	lazygit = utf8.char(0xe702),
	node = utf8.char(0xe718),
	npm = utf8.char(0xe71e),
	bun = utf8.char(0xe718),
	python = utf8.char(0xe73c),
	python3 = utf8.char(0xe73c),
	cargo = utf8.char(0xe7a8),
	rustc = utf8.char(0xe7a8),
	go = utf8.char(0xe627),
	lua = utf8.char(0xe620),
	docker = utf8.char(0xf308),
	ssh = utf8.char(0xf233),
	top = utf8.char(0xf080),
	htop = utf8.char(0xf080),
	btop = utf8.char(0xf080),
	make = utf8.char(0xf085),
	brew = utf8.char(0xf0f4),
}
local ICON_DEFAULT = utf8.char(0xf120) -- 

-- Flat segments: accented icon, muted text, hairline divider between them.
-- Nothing sets a Background, so every segment inherits the bar background.
local function render(segments, palette)
	local elements = {}

	for i, seg in ipairs(segments) do
		if i > 1 then
			table.insert(elements, { Foreground = { Color = palette.surface1 } })
			table.insert(elements, { Text = "  " .. DIVIDER .. "  " })
		end
		table.insert(elements, { Foreground = { Color = palette[seg.accent] } })
		table.insert(elements, { Text = seg.icon .. " " })
		table.insert(elements, { Foreground = { Color = palette.subtext0 } })
		table.insert(elements, { Text = seg.text })
	end

	return elements
end

local function basename(path)
	return path:match("([^/\\]+)$") or path
end

-- get_current_working_dir() returns a Url on current WezTerm and a plain
-- file:// string on older builds; accept either.
local function pane_cwd(pane)
	local ok, cwd = pcall(function()
		return pane:get_current_working_dir()
	end)
	if not ok or cwd == nil then
		return nil
	end

	local path
	if type(cwd) == "string" then
		path = cwd:gsub("^file://[^/]*", "")
	else
		path = cwd.file_path
	end
	if path == nil or path == "" then
		return nil
	end

	path = path:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end)
	path = path:gsub("(.)/$", "%1")

	local home = os.getenv("HOME")
	if home and path:sub(1, #home) == home then
		path = "~" .. path:sub(#home + 1)
	end

	return path
end

-- Keep the last `keep` path components, the way starship truncates.
local function truncate_path(path, keep)
	local parts = {}
	for part in path:gmatch("[^/]+") do
		parts[#parts + 1] = part
	end
	if #parts == 0 then
		return "/"
	end
	if #parts <= keep then
		return table.concat(parts, "/")
	end
	return "…/" .. table.concat(parts, "/", #parts - keep + 1)
end

local function process_icon(name)
	name = basename(name or ""):gsub("%.exe$", "")
	return PROCESS_ICONS[name] or ICON_DEFAULT, name
end

function M.apply(config, palette, background)
	wezterm.on("format-tab-title", function(tab, _, _, _, hover, max_width)
		local pane = tab.active_pane

		local icon, proc = process_icon(pane.foreground_process_name)
		local title = tab.tab_title
		if title == nil or #title == 0 then
			title = proc ~= "" and proc or (pane.title or "shell")
		end
		title = wezterm.truncate_right(title, math.max(6, max_width - 8))

		-- The active tab is the only thing allowed to carry full colour.
		local fg = palette.overlay1
		if tab.is_active then
			fg = palette.mauve
		elseif hover then
			fg = palette.subtext0
		end

		-- Set the background on every run. Without it the cells keep whatever
		-- fill the colour scheme gives the tab, which for Catppuccin is a solid
		-- mauve block the mauve active-tab text then vanishes into.
		local elements = { { Background = { Color = background } } }

		if tab.tab_index > 0 then
			table.insert(elements, { Foreground = { Color = palette.surface1 } })
			table.insert(elements, { Text = DIVIDER })
		end

		-- A bar in the accent colour marks the current tab. Inactive tabs pad
		-- with a space instead, so titles keep their column as focus moves.
		table.insert(elements, { Foreground = { Color = palette.mauve } })
		table.insert(elements, { Text = tab.is_active and " " .. ACTIVE_MARK or "  " })

		table.insert(elements, { Foreground = { Color = fg } })
		table.insert(elements, { Attribute = { Intensity = tab.is_active and "Bold" or "Normal" } })
		table.insert(elements, { Text = " " .. icon .. "  " .. title })

		if not tab.is_active and pane.has_unseen_output then
			table.insert(elements, { Foreground = { Color = palette.yellow } })
			table.insert(elements, { Text = " " .. ICON_UNSEEN })
		end

		table.insert(elements, { Attribute = { Intensity = "Normal" } })
		table.insert(elements, { Foreground = { Color = fg } })
		table.insert(elements, { Text = "  " })

		return elements
	end)

	wezterm.on("update-status", function(window, pane)
		local left = render({
			{ icon = ICON_WORKSPACE, text = window:active_workspace(), accent = "mauve" },
		}, palette)
		table.insert(left, 1, { Text = "  " })
		table.insert(left, { Text = "  " })
		window:set_left_status(wezterm.format(left))

		local segments = {}

		local cwd = pane_cwd(pane)
		if cwd then
			segments[#segments + 1] = {
				icon = ICON_FOLDER,
				text = truncate_path(cwd, 3),
				accent = "blue",
			}
		end

		segments[#segments + 1] = {
			icon = ICON_CLOCK,
			text = wezterm.strftime("%H:%M"),
			accent = "overlay1",
		}

		local right = render(segments, palette)
		table.insert(right, { Text = "  " })
		window:set_right_status(wezterm.format(right))
	end)
end

return M
