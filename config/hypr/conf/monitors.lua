-- https://wiki.hypr.land/Configuring/Basics/Monitors/

-- Catch-all: whatever the panel reports as native.
--
-- Deliberately "preferred" and not "highres". A 27" 1440p panel will happily
-- advertise a downscaled 3840x2160 mode over HDMI, and highres takes it --
-- which at scale 1 is 162 DPI and renders the whole desktop microscopic.
-- preferred takes the EDID's native mode instead, so a fresh install is
-- legible before anyone touches a config.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

-- Per-machine overrides. install.sh seeds this from monitors_local.lua.example
-- and git ignores it, so a display layout never travels with the repo. The
-- last matching rule wins, so anything in there beats the catch-all above.
pcall(require, "conf.monitors_local")
