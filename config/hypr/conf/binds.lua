-- Ported from hypr_starter_backup/configs/Keybinds.conf (JaKooLit defaults).
-- Every bind that shelled out to a script was dropped, not reimplemented.
-- https://wiki.hypr.land/Configuring/Basics/Binds/

local mod = theme.mainMod
local apps = theme.apps

local function d(text)
	return { description = text }
end
local function opts(text, extra)
	extra = extra or {}
	extra.description = text
	return extra
end

-- Every modal panel takes exclusive keyboard focus, so only one may be open.
-- bin/qs-panel closes the rest before toggling the one asked for; see its
-- header for why that lives in a script rather than in each module.
local function panel(name)
	return hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/bin/qs-panel " .. name)
end

---- LAUNCHERS ----
hl.bind(mod .. " + SPACE", panel("launcher"), d("wheel launcher"))
hl.bind(mod .. " + C", panel("control"), d("control panel"))
hl.bind(mod .. " + N", panel("nodemap"), d("container node map"))
hl.bind(mod .. " + A", panel("agent"), d("agent activity"))
hl.bind(mod .. " + O", panel("expose"), d("workspace expose"))
hl.bind(mod .. " + R", panel("dev"), d("project ignition"))
hl.bind(mod .. " + L", hl.dsp.exec_cmd("qs -c lock ipc call lock engage"), d("lock session"))
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(apps.terminal), d("open terminal"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(apps.fileManager), d("file manager"))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(apps.browser), d("open default browser"))
-- Reads `hyprctl binds -j`, so it lists exactly what is bound here -- every
-- one of these lines already carries the description it shows.
hl.bind(mod .. " + SHIFT + P", panel("radar"), d("socket & port radar"))
hl.bind(mod .. " + W", panel("palette"), d("theme & wallpaper studio"))
hl.bind(mod .. " + H", panel("sensor"), d("hardware sensors & avionics"))
hl.bind(mod .. " + Y", panel("cyberpad"), d("cyberdeck scratchpad console"))
hl.bind(mod .. " + M", panel("music"), d("cyberdeck music player"))
hl.bind(mod .. " + S", panel("spectrum"), d("spectrum audio & volume console"))
hl.bind(mod .. " + X", panel("schematic"), d("schematic vector studio"))
hl.bind(mod .. " + slash", panel("keys"), d("keybind cheatsheet"))

---- SYSTEM ----
hl.bind("CTRL + ALT + Delete", hl.dsp.exit(), d("exit Hyprland"))
hl.bind(mod .. " + Q", hl.dsp.window.close(), d("close active window"))
hl.bind(mod .. " + SHIFT + N", panel("notify"), d("notification history"))
hl.bind("XF86Sleep", hl.dsp.exec_cmd("systemctl suspend"), opts("sleep", { locked = true }))

---- CLIPBOARD ----
-- cliphist owns the store; the `clip` module only reads it. Wiping lives
-- inside the panel (CTRL+W, armed) rather than on a keybind of its own --
-- a single keystroke that empties the clipboard history is a keystroke that
-- will eventually be hit by accident.
hl.bind(mod .. " + V", panel("clip"), d("clipboard history"))

---- TODO ----
-- The only module that owns its own data; the store is
-- ~/.local/share/hypr/todo.json and it is watched, so editing that file by
-- hand shows up in the panel without a restart.
hl.bind(mod .. " + T", panel("todo"), d("todo list"))

---- SCREENSHOT ----
-- grim/slurp/satty were all installed and not one of them was bound.
-- `-f` freezes the screen before the region drag, so the thing you are
-- selecting cannot move out from under the selection; `-n` notifies, which
-- the quickshell `notify` module now answers.
local shots = "~/Pictures"
local function shot(args)
	return hl.dsp.exec_cmd("grimblast -f -n " .. args .. " " .. shots .. "/shot-$(date +%Y%m%d-%H%M%S).png")
end

-- Region to clipboard AND disk: the default, because deciding which one you
-- wanted after the fact is not possible and a PNG is cheap.
hl.bind("Print", shot("copysave area"), d("screenshot region"))
hl.bind(mod .. " + SHIFT + S", shot("copysave area"), d("screenshot region"))
hl.bind("CTRL + Print", shot("copysave output"), d("screenshot whole screen"))
hl.bind("ALT + Print", shot("copysave active"), d("screenshot active window"))
-- Annotate first, then satty decides where it goes (its own copy/save keys).
hl.bind(
	"SHIFT + Print",
	hl.dsp.exec_cmd(
		"grimblast -f save area - | satty -f - --early-exit --copy-command wl-copy"
			.. " -o " .. shots .. "/shot-%Y%m%d-%H%M%S.png"
	),
	d("screenshot region, annotate")
)
-- Pick a colour off the screen into the clipboard. hyprpicker was installed
-- for grimblast's sake and is useful on its own.
hl.bind(
	mod .. " + SHIFT + C",
	hl.dsp.exec_cmd("hyprpicker -a -n"),
	d("pick colour to clipboard")
)

---- WINDOW STATE ----
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), d("fullscreen"))
hl.bind(mod .. " + CTRL + F", hl.dsp.window.fullscreen({ mode = "maximized" }), d("maximize window"))
hl.bind(mod .. " + tab", hl.dsp.window.float({ action = "toggle" }), d("float current window"))
hl.bind(mod .. " + P", hl.dsp.layout("fit expand"), d("expand into free space"))
hl.bind(mod .. " + CTRL + O", hl.dsp.window.set_prop({ prop = "opaque", value = "toggle" }), d("toggle window opacity"))
-- The old `workspaceopt allfloat` has no hl.dsp binding, and hyprctl dispatch now
-- evaluates lua, so it can't be shelled out to either. Done directly instead.
hl.bind(mod .. " + ALT + SPACE", function()
	local ws = hl.get_active_workspace()
	if not ws then
		return
	end

	local windows = hl.get_workspace_windows(ws)
	-- Anything still tiled means "float everything"; otherwise put them all back.
	local target = false
	for _, w in ipairs(windows) do
		if not w.floating then
			target = true
			break
		end
	end

	for _, w in ipairs(windows) do
		if w.floating ~= target then
			hl.dispatch(hl.dsp.window.float({ action = "toggle", window = w }))
		end
	end
end, d("float / unfloat all windows"))

---- LAYOUT (scrolling) ----
-- These keys used to drive master/dwindle. Same keys, scrolling equivalents.
hl.bind(mod .. " + I", hl.dsp.layout("consume_or_expel next"), d("consume/expel window into column"))
hl.bind(mod .. " + SHIFT + I", hl.dsp.layout("promote"), d("move window to its own column"))
hl.bind(mod .. " + CTRL + D", hl.dsp.layout("expel"), d("expel window to a new column"))
hl.bind(mod .. " + CTRL + Return", hl.dsp.layout("swapcol r"), d("swap column right"))
hl.bind(mod .. " + M", hl.dsp.layout("colresize +conf"), d("cycle column width"))
hl.bind(mod .. " + SHIFT + M", hl.dsp.layout("fit_into_view"), d("fit column into view"))

---- FOCUS / MOVE / SWAP / RESIZE ----
for key, dir in pairs({ left = "l", right = "r", up = "u", down = "d" }) do
	hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }), d("focus " .. key))
	hl.bind(mod .. " + CTRL + " .. key, hl.dsp.window.move({ direction = dir }), d("move window " .. key))
	hl.bind(mod .. " + ALT + " .. key, hl.dsp.window.swap({ direction = dir }), d("swap window " .. key))
end

local resize = { left = { -50, 0 }, right = { 50, 0 }, up = { 0, -50 }, down = { 0, 50 } }
for key, delta in pairs(resize) do
	hl.bind(
		mod .. " + SHIFT + " .. key,
		hl.dsp.window.resize({ x = delta[1], y = delta[2], relative = true }),
		opts("resize " .. key, { repeating = true })
	)
end

-- Cycle windows; if floating, bring to top
hl.bind("ALT + tab", function()
	hl.dispatch(hl.dsp.window.cycle_next())
	hl.dispatch(hl.dsp.window.bring_to_top())
end, d("cycle next window"))

---- GROUPS ----
hl.bind(mod .. " + G", hl.dsp.group.toggle(), d("toggle group"))
hl.bind(mod .. " + CTRL + tab", hl.dsp.group.next(), d("change active in group"))
hl.bind(mod .. " + CTRL + K", hl.dsp.window.move({ into_group = "l" }), d("move left into group"))
hl.bind(mod .. " + CTRL + L", hl.dsp.window.move({ into_group = "r" }), d("move right into group"))
hl.bind(mod .. " + CTRL + H", hl.dsp.window.move({ out_of_group = true }), d("move active out of group"))

---- WORKSPACES ----
-- code:10..19 map to keys 1..0, so this survives non-QWERTY layouts.
for i = 1, 10 do
	local code = "code:" .. (9 + i)
	hl.bind(mod .. " + " .. code, hl.dsp.focus({ workspace = i }), d("workspace " .. i))
	hl.bind(
		mod .. " + SHIFT + " .. code,
		hl.dsp.window.move({ workspace = i, follow = true }),
		d("move to workspace " .. i)
	)
	hl.bind(
		mod .. " + CTRL + " .. code,
		hl.dsp.window.move({ workspace = i, follow = false }),
		d("move silently to workspace " .. i)
	)
end

-- The volume rocker doubles as a switcher: SUPER + rocker walks workspaces,
-- and with SUPER+tab held it walks windows inside the current one. Tab is not
-- a modifier, so the mode is read off the physical key instead of a submap --
-- and SUPER+tab itself is a no_op purely to swallow the tab from the focused
-- window while it is held.
local function rocker(ws, cycle)
	return function()
		if hl.is_key_down("Tab") then
			hl.dispatch(cycle)
			hl.dispatch(hl.dsp.window.bring_to_top())
		else
			hl.dispatch(hl.dsp.focus({ workspace = ws }))
		end
	end
end
hl.bind(
	mod .. " + XF86AudioRaiseVolume",
	rocker("m+1", hl.dsp.window.cycle_next()),
	opts("next workspace (hold tab: next window)", { repeating = true })
)
hl.bind(
	mod .. " + XF86AudioLowerVolume",
	rocker("m-1", hl.dsp.window.cycle_next({ next = false })),
	opts("previous workspace (hold tab: previous window)", { repeating = true })
)
hl.bind(mod .. " + tab", hl.dsp.no_op(), d("hold with the volume rocker to switch windows"))
hl.bind(mod .. " + SHIFT + tab", hl.dsp.focus({ workspace = "m-1" }), d("previous workspace"))
hl.bind(mod .. " + period", hl.dsp.focus({ workspace = "e+1" }), d("next workspace"))
hl.bind(mod .. " + comma", hl.dsp.focus({ workspace = "e-1" }), d("previous workspace"))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), d("next workspace"))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), d("previous workspace"))
hl.bind(
	mod .. " + SHIFT + bracketleft",
	hl.dsp.window.move({ workspace = "-1", follow = true }),
	d("move to previous workspace")
)
hl.bind(
	mod .. " + SHIFT + bracketright",
	hl.dsp.window.move({ workspace = "+1", follow = true }),
	d("move to next workspace")
)
hl.bind(
	mod .. " + CTRL + bracketleft",
	hl.dsp.window.move({ workspace = "-1", follow = false }),
	d("move silently to previous workspace")
)
hl.bind(
	mod .. " + CTRL + bracketright",
	hl.dsp.window.move({ workspace = "+1", follow = false }),
	d("move silently to next workspace")
)

-- Special workspace (scratchpad)
hl.bind(mod .. " + escape", hl.dsp.workspace.toggle_special("scratch"), d("drop-down scratchpad"))
hl.bind(mod .. " + U", hl.dsp.workspace.toggle_special(), d("toggle special workspace"))
hl.bind(mod .. " + SHIFT + U", hl.dsp.window.move({ workspace = "special" }), d("move to special workspace"))

-- Move current workspace to another monitor
for key, dir in pairs({ F9 = "l", F10 = "r", F11 = "u", F12 = "d" }) do
	hl.bind(
		mod .. " + CTRL + " .. key,
		hl.dsp.workspace.move({ monitor = dir }),
		d("move workspace to " .. dir .. " monitor")
	)
end

---- MOUSE ----
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), opts("move window", { mouse = true }))
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), opts("resize window", { mouse = true }))

---- ZOOM / MAGNIFIER ----
-- Pure lua now; the old config shelled out to hyprctl + awk for this.
local function zoom(factor)
	return function()
		local current = math.max(tonumber(hl.get_config("cursor.zoom_factor")) or 1, 1)
		hl.config({ cursor = { zoom_factor = current * factor } })
	end
end
hl.bind(mod .. " + ALT + mouse_down", zoom(2.0), d("zoom in"))
hl.bind(mod .. " + ALT + mouse_up", zoom(0.5), d("zoom out"))

---- MEDIA / BRIGHTNESS ----
-- Native tools, not the Volume.sh / MediaCtrl.sh wrappers.
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true, description = "volume up" }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true, description = "volume down" }
)
-- Fallback volume keys for keyboards without dedicated media keys
hl.bind(
	mod .. " + equal",
	hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ repeating = true, description = "volume up" }
)
hl.bind(
	mod .. " + minus",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ repeating = true, description = "volume down" }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, description = "toggle mute" }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, description = "toggle mic mute" }
)
hl.bind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),
	{ locked = true, repeating = true, description = "brightness up" }
)
hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),
	{ locked = true, repeating = true, description = "brightness down" }
)

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "next track" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "previous track" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "play" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "pause" })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true, description = "stop" })
