-- Hyprland loads this file when it is started without a config, and it prefers
-- it over hyprland.conf. HyDE loads it too, last, as the override layer below.
-- The block keeps the two apart: hyde.lua sets `hyde` on its first line, so it
-- runs only when this file is the entry point and HyDE has not been loaded.
-- Removing it leaves a session with a cursor and nothing else.
if not hyde then
	local share = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
	local entry = share .. "/hypr/hyde.lua"
	local handle = io.open(entry, "r")
	if not handle then
		error("HyDE is not installed at " .. entry .. ". Run install.sh -r, or point Hyprland at your own config.")
	end
	handle:close()
	dofile(entry)
end

-- Your Hyprland configuration. HyDE never overwrites this file.
--
-- It loads after HyDE's own binds, so settings here take precedence. Replacing
-- a bind needs more than that: see below. HyDE's defaults live in
-- ~/.local/share/hypr/lua/ and are overwritten on every update, so edits there
-- do not survive.
--
-- Adding a keybind:
--
--     hl.bind("SUPER + SPACE", hl.dsp.exec_cmd(hyde.sh.gamelauncher()), {
--         description = "[Utilities] game launcher",
--     })
--
-- Replacing one of HyDE's: bind the same combination again and yours takes
-- over, but copy its flags across as well. A bind counts as the same one only
-- when its flags match, and `description` is not a flag — miss one and both
-- binds stay live on that combination. Copy the whole options table from
-- ~/.local/share/hypr/lua/key_binds.lua and change only what you need:
--
--     hl.bind("F9", hl.dsp.exec_cmd(hyde.sh.volumecontrol("-o", "m")), {
--         locked = true,
--         description = "[Hardware Controls|Audio] un/mute output",
--     })
--
-- Press SUPER + / to see what is actually loaded, your own binds included.
-- The full reference is KEYBINDINGS.md in the HyDE repository.
--
-- Other Lua files next to this one can be pulled in with require("name").

-- Per-monitor scaling: keep the laptop readable without the aggressive auto 1.5 scale.
hl.monitor({
	output = "eDP-1",
	mode = "preferred",
	position = "0x0",
	scale = 1.25,
})

hl.monitor({
	output = "desc:LG Electronics LG ULTRAGEAR 506NTFAF3659",
	mode = "preferred",
	position = "1536x0",
	scale = 1,
})

-- Personal window spacing: keep theme colors, with subtler borders and gaps.
hl.config({
	cursor = {
		-- Use the native Future-cyan Hyprcursor build; XCursor remains the fallback.
		enable_hyprcursor = true,
	},
	input = {
		kb_layout = "es,latam",
	},
	general = {
		border_size = 2,
		gaps_in = 2,
		gaps_out = 4,
	},
	decoration = {
		rounding = 8,
		active_opacity = 1,
		inactive_opacity = 1,
		fullscreen_opacity = 1,
		blur = {
			enabled = false,
			popups = false,
			special = false,
		},
	},
})

-- Keep application windows opaque without forcing RGBX, which can damage rounded edges.
hl.window_rule({
	name = "user_opaque_windows",
	match = { class = ".*" },
	opaque = true,
})

-- HyDE launchers and notifications are layer surfaces, so disable their blur separately.
hl.layer_rule({
	name = "user_disable_layer_blur",
	match = {
		namespace = "^(rofi|notifications|swaync-(notification-window|control-center)|logout_dialog|waybar)$",
	},
	blur = false,
	blur_popups = false,
})

-- Faster global animations while preserving the current easing and effects.
hl.animation({
	leaf = "global",
	enabled = true,
	speed = 5,
	bezier = "default",
})

-- Keep the user-selected readable fonts after theme changes and reloads.
local function set_interface_font(key, value)
	if value and value ~= "" then
		hl.exec_cmd(string.format("gsettings set org.gnome.desktop.interface %s %q", key, tostring(value)))
	end
end

set_interface_font("font-name", hyde.config.ui.font .. " " .. hyde.config.ui.font_size)
set_interface_font("document-font-name", hyde.config.ui.document_font .. " " .. hyde.config.ui.document_font_size)
set_interface_font("monospace-font-name", hyde.config.ui.monospace_font .. " " .. hyde.config.ui.monospace_font_size)
set_interface_font("font-antialiasing", hyde.config.ui.font_antialiasing)
set_interface_font("font-hinting", hyde.config.ui.font_hinting)
