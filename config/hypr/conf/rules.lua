-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/ https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

hl.window_rule({
	-- Ignore maximize requests from all apps. You'll probably like this.
	name = "suppress-maximize-events",
	match = { class = ".*" },

	suppress_event = "maximize",
})

hl.window_rule({
	-- Fix some dragging issues with XWayland
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},

	no_focus = true,
})

hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },

	move = "20 monitor_h-120",
	float = true,
})

-- "Smart gaps" / no gaps when only one window. Uncomment all four to use.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({ name = "no-gaps-wtv1", match = { float = false, workspace = "w[tv1]" }, border_size = 0, rounding = 0 })
-- hl.window_rule({ name = "no-gaps-f1",   match = { float = false, workspace = "f[1]"   }, border_size = 0, rounding = 0 })

----------------------------------------------------------------------------
---- QUICKSHELL LAYER RULES ----
-- Compositor blur on all quickshell modals, overlays and glass surfaces
hl.layer_rule({
	name = "quickshell-modal-blur",
	match = {
		namespace = "^quickshell:(deck|launcher|control|radar|music|schematic|cyberpad|sensor|palette|todo|clip|keys|notifypanel|notify|dev|agent|nodemap|expose|auth)$",
	},
	blur = true,
	ignore_alpha = 0.2,
})

----------------------------------------------------------------------------
---- SCRATCHPAD ----
-- A quake-style drop-down terminal on the `scratch` special workspace.
-- SUPER + grave toggles it; Hyprland slides and blurs it over whatever is
-- already on screen. Nothing runs until the first time you open it.

hl.workspace_rule({
	workspace = "special:scratch",
	-- Spawned once, on first open. No daemon, no autostart, no stale process.
	on_created_empty = "kitty --class scratchpad -e zsh",
	gaps_in = 0,
	gaps_out = 0,
	border_size = 0,
	no_shadow = true,
})

hl.window_rule({
	name = "scratchpad-dropdown",
	match = { class = "^scratchpad$" },

	float = true,
	size = { "(monitor_w)", "(monitor_h*0.45)" },
	move = { 0, 0 },
	-- Slightly translucent so the blur behind it actually reads.
	opacity = "0.94 0.94",
	animation = "slidevert",
})
