-- Curve library from the "End-4" preset; the animation wiring is ours.
-- Originally ported from hypr_starter_backup/UserConfigs/UserAnimations.conf
-- credit https://github.com/end-4/dots-hyprland
-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/

hl.config({ animations = { enabled = true } })

-- The curve list is still the preset's; the wiring below is not. Windows now
-- slide on easeOutExpo and borders do not animate at all -- MD3's easing is
-- phone-app motion and this desktop is instruments.
hl.curve("linear",        { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("md3_standard",  { type = "bezier", points = { {0.2, 0},     {0, 1}       } })
hl.curve("md3_decel",     { type = "bezier", points = { {0.05, 0.7},  {0.1, 1}     } })
hl.curve("md3_accel",     { type = "bezier", points = { {0.3, 0},     {0.8, 0.15}  } })
hl.curve("overshot",      { type = "bezier", points = { {0.05, 0.9},  {0.1, 1.1}   } })
hl.curve("crazyshot",     { type = "bezier", points = { {0.1, 1.5},   {0.76, 0.92} } })
hl.curve("hyprnostretch", { type = "bezier", points = { {0.05, 0.9},  {0.1, 1.0}   } })
hl.curve("menu_decel",    { type = "bezier", points = { {0.1, 1},     {0, 1}       } })
hl.curve("menu_accel",    { type = "bezier", points = { {0.38, 0.04}, {1, 0.07}    } })
hl.curve("easeInOutCirc", { type = "bezier", points = { {0.85, 0},    {0.15, 1}    } })
hl.curve("easeOutCirc",   { type = "bezier", points = { {0, 0.55},    {0.45, 1}    } })
hl.curve("easeOutExpo",   { type = "bezier", points = { {0.16, 1},    {0.3, 1}     } })
hl.curve("softAcDecel",   { type = "bezier", points = { {0.26, 0.26}, {0.15, 1}    } })
hl.curve("md2",           { type = "bezier", points = { {0.4, 0},     {0.2, 1}     } })  -- use with .2s duration

-- The scratchpad drop. A spring rather than a bezier so it has weight and
-- settles, instead of easing to a dead stop. Kept deliberately: the drop-down
-- is the one surface where weight is the point. Everything else is mechanical
-- and does not overshoot.
hl.curve("drop", { type = "spring", mass = 1, stiffness = 190, dampening = 21 })

-- Windows slide along the scrolling axis instead of inflating from their
-- centre. `popin` tells you nothing about where a window went; in a scrolling
-- layout the direction of travel IS the information, so motion teaches the
-- spatial model rather than decorating it.
hl.animation({ leaf = "windows",          enabled = true, speed = 3.4, bezier = "easeOutExpo", style = "slide" })
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 3.4, bezier = "easeOutExpo", style = "slide" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 4.6, bezier = "menu_accel",  style = "slide" })
-- Borders cut. The border is a state readout, not a moving part: fading it
-- means focus is ambiguous for the length of the fade.
hl.animation({ leaf = "border",           enabled = false })
hl.animation({ leaf = "fade",             enabled = true, speed = 3,   bezier = "md3_decel" })
hl.animation({ leaf = "layersIn",         enabled = true, speed = 3,   bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "layersOut",        enabled = true, speed = 1.6, bezier = "menu_accel" })
hl.animation({ leaf = "fadeLayersIn",     enabled = true, speed = 2,   bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut",    enabled = true, speed = 4.5, bezier = "menu_accel" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 7,   bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4,   spring = "drop",       style = "slidevert" })
