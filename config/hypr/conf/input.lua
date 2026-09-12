-- https://wiki.hypr.land/Configuring/Basics/Variables/#input

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,
        sensitivity  = 0,   -- -1.0 to 1.0, 0 = no modification

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

-- Per-device config: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/
-- hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })
