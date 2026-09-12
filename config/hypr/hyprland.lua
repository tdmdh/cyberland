-- Entry point. Config lives in conf/, tweakables live in theme.lua.
-- Wiki: https://wiki.hypr.land/Configuring/Start/

-- Global on purpose: each require() runs in its own scope, so a local here
-- would be invisible to conf/*. One global beats a require line in every file.
theme = require("theme")

require("conf.monitors")
require("conf.looknfeel")   -- must come before anything that overrides it
require("conf.animations")
require("conf.input")
require("conf.binds")
require("conf.rules")
require("conf.autostart")
