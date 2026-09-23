-- WezTerm configuration.
--
-- Catppuccin (https://github.com/catppuccin/wezterm) for colour, plus a
-- powerline tab bar and status line shaped like the starship prompt in
-- ~/.config/starship.toml. See catppuccin.lua for the palettes and bar.lua for
-- the bar itself.

local wezterm = require("wezterm")
local catppuccin = require("catppuccin")
local bar = require("bar")

-- The one knob: "mocha", "macchiato", "frappe" or "latte".
-- starship.toml is pinned to catppuccin_mocha, so change both together.
local FLAVOR = "mocha"

local palette = catppuccin.palettes[FLAVOR]

-- Every flavour carries three background tones, lightest to darkest: base,
-- mantle, crust. The window and the tab bar share this one so they stay
-- matched -- darken them apart and the bar becomes a visible strip again.
local BACKGROUND = palette.mantle

local config = wezterm.config_builder()

-- ---------------------------------------------------------------- colour ---

config.color_scheme = catppuccin.scheme_names[FLAVOR]
config.command_palette_bg_color = BACKGROUND
config.command_palette_fg_color = palette.text

-- Every tab background matches the window background, so the tab bar reads as
-- part of the terminal rather than as a separate chrome strip, and the window's
-- transparency and blur pass through it.
--
-- All five states are spelled out on purpose. The built-in Catppuccin scheme
-- fills the active tab with mauve (#cba6f7); overriding only `background` here
-- leaves that fill in place, and bar.lua then draws mauve text on it -- an
-- unreadable purple block. The active tab is marked with colour and a bar in
-- bar.lua instead, so nothing here paints a fill.
config.colors = {
	background = BACKGROUND,
	tab_bar = {
		background = BACKGROUND,
		active_tab = { bg_color = BACKGROUND, fg_color = palette.mauve },
		inactive_tab = { bg_color = BACKGROUND, fg_color = palette.overlay1 },
		inactive_tab_hover = { bg_color = BACKGROUND, fg_color = palette.subtext0 },
		new_tab = { bg_color = BACKGROUND, fg_color = palette.overlay1 },
		new_tab_hover = { bg_color = BACKGROUND, fg_color = palette.subtext0 },
	},
	visual_bell = palette.surface0,
}

-- Only read for the fancy tab bar, kept so a switch back stays on-theme.
config.window_frame = {
	font = wezterm.font({ family = "JetBrainsMono Nerd Font", weight = "Bold" }),
	font_size = 12.0,
	active_titlebar_bg = BACKGROUND,
	inactive_titlebar_bg = BACKGROUND,
	active_titlebar_fg = palette.text,
	inactive_titlebar_fg = palette.subtext0,
	button_fg = palette.text,
	button_bg = palette.base,
}

-- ------------------------------------------------------------------ font ---

config.font = wezterm.font_with_fallback({
	{ family = "JetBrainsMono Nerd Font", weight = "Medium" },
	{ family = "Symbols Nerd Font Mono", scale = 0.9 },
	"Apple Color Emoji",
})
config.font_size = 13.5
config.line_height = 1.15
config.harfbuzz_features = { "calt=1", "clig=1", "liga=1" }
config.adjust_window_size_when_changing_font_size = false

-- ---------------------------------------------------------------- window ---

config.window_decorations = "RESIZE"
config.window_background_opacity = 0.90
config.macos_window_background_blur = 40
config.window_padding = { left = 16, right = 16, top = 6, bottom = 8 }
config.initial_cols = 120
config.initial_rows = 34
config.scrollback_lines = 10000

-- --------------------------------------------------------------- tab bar ---

-- The retro tab bar is the one that renders wezterm.format output, so it is
-- what makes the powerline segments in bar.lua possible.
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = false
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 32

-- ------------------------------------------------------- cursor and panes ---

config.default_cursor_style = "BlinkingBar"
config.cursor_blink_rate = 600
config.cursor_blink_ease_in = "EaseOut"
config.cursor_blink_ease_out = "EaseOut"
config.animation_fps = 60
config.inactive_pane_hsb = { saturation = 0.9, brightness = 0.7 }

-- ------------------------------------------------------------------ bell ---

config.audible_bell = "Disabled"
config.visual_bell = {
	fade_in_duration_ms = 75,
	fade_out_duration_ms = 75,
	fade_in_function = "EaseOut",
	fade_out_function = "EaseIn",
}

-- ------------------------------------------------------------------ keys ---

-- Splits and pane navigation, which macOS WezTerm otherwise leaves on awkward
-- CTRL+SHIFT+ALT chords. Delete this block for stock key assignments.
config.keys = {
	{ key = "d", mods = "CMD", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "d", mods = "CMD|SHIFT", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "[", mods = "CMD", action = wezterm.action.ActivatePaneDirection("Prev") },
	{ key = "]", mods = "CMD", action = wezterm.action.ActivatePaneDirection("Next") },
	{ key = "w", mods = "CMD", action = wezterm.action.CloseCurrentPane({ confirm = true }) },
	{ key = "Enter", mods = "CMD|SHIFT", action = wezterm.action.TogglePaneZoomState },
	-- CTRL+SHIFT+K is herdr's previous_workspace; WezTerm binds it to
	-- ClearScrollback by default. CMD+K still clears.
	{ key = "K", mods = "CTRL", action = wezterm.action.DisableDefaultAssignment },
	{ key = "K", mods = "CTRL|SHIFT", action = wezterm.action.DisableDefaultAssignment },
	{ key = "k", mods = "CTRL|SHIFT", action = wezterm.action.DisableDefaultAssignment },
}

bar.apply(config, palette, BACKGROUND)

return config
