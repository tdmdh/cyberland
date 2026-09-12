-- https://wiki.hypr.land/Configuring/Basics/Variables/

hl.config({
	general = {
		gaps_in = theme.gaps_in,
		gaps_out = theme.gaps_out,
		border_size = theme.border,

		col = {
			active_border = theme.colors.active_border,
			inactive_border = theme.colors.inactive_border,
		},

		resize_on_border = false,
		allow_tearing = false, -- read the wiki on Tearing before enabling
		layout = "scrolling",
	},

	decoration = {
		rounding = theme.rounding,
		active_opacity = 1.0,
		inactive_opacity = 0.94,

		-- Unfocused windows recede instead of competing for attention.
		dim_inactive = true,
		dim_strength = 0.22,

		-- Darken what's behind the scratchpad while it's down.
		dim_special  = 0.4,

		-- The focused window gets a coloured halo in the wallpaper's accent.
		glow = {
			enabled = false,
			color = theme.colors.glow,
			color_inactive = theme.colors.glow_inactive,
			range = 6,
			render_power = 2,
		},

		-- Hard-edged drop shadow rather than a soft blur, to match the geometry.
		shadow = {
			enabled = false,
			sharp = true,
			range = 12,
			render_power = 1,
			color = theme.colors.shadow,
		},

		-- Vibrancy and noise are both off: vibrancy re-saturates whatever is
		-- behind the panel, which fights a single-hue palette, and noise is
		-- texture in a design that is meant to read as drawn.
		blur = {
			enabled = true,
			size = 6,
			passes = 3,
			noise = 0.0,
			vibrancy = 0.0,
			new_optimizations = true,
			special           = true,   -- blur behind the scratchpad overlay
			popups            = true,
		},
	},

	scrolling = { fullscreen_on_one_column = true },

	misc = {
		force_default_wallpaper = -1, -- 0 or 1 disables the anime mascot wallpapers
		disable_hyprland_logo = false,

		-- Both default to FALSE. The idle chain turns the display off after
		-- 15 minutes, and without these a keypress or mouse move does not
		-- bring it back -- you get a black screen that looks like a dead
		-- machine. The compositor sees input before quickshell does, so
		-- waking belongs here rather than in resume handling.
		key_press_enables_dpms = true,
		mouse_move_enables_dpms = true,
	},
})
