return {
  -- =========================================================================
  -- 1. Snacks Dashboard & Notifier (Tokyo Cyber-Avionics)
  -- =========================================================================
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = [[
 ████████╗ ██████╗ ██╗  ██╗██╗   ██╗ ██████╗ 
 ╚══██╔══╝██╔═══██╗██║ ██╔╝╚██╗ ██╔╝██╔═══██╗
    ██║   ██║   ██║█████╔╝  ╚████╔╝ ██║   ██║
    ██║   ██║   ██║██╔═██╗   ╚██╔╝  ██║   ██║
    ██║   ╚██████╔╝██║  ██╗   ██║   ╚██████╔╝
    ╚═╝    ╚═════╝ ╚═╝  ╚═╝   ╚═╝    ╚═════╝ 
       [ 東京電脳 · AVIONICS FLIGHT DECK ]
]],
          keys = {
            { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = " ", key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = " ", key = "s", desc = "Restore Session", section = "session" },
            { icon = "󰒲 ", key = "l", desc = "Lazy Plugins", action = ":Lazy" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
          function()
            local p = require("tokyo.palette").get()
            local wall_src = vim.fn.expand("~/.cache/hypr/wallpaper-source")
            local wall = "DEFAULT"
            local wf = io.open(wall_src, "r")
            if wf then
              local line = wf:read("*l")
              wf:close()
              if line then
                wall = vim.fn.fnamemodify(line, ":t")
              end
            end
            return {
              align = "center",
              padding = 1,
              text = {
                { "• TOKYO SYSTEM TELEMETRY •\n", hl = "Comment" },
                { "WALLPAPER: ", hl = "Comment" },
                { wall .. "  │  ", hl = "Special" },
                { "ACCENT: ", hl = "Comment" },
                { p.accent, hl = "Special" },
              },
            }
          end,
        },
      },
      notifier = {
        style = "compact",
        border = "single",
      },
    },
  },

  -- =========================================================================
  -- 2. WhichKey (Sharp Hairline Border)
  -- =========================================================================
  {
    "folke/which-key.nvim",
    opts = {
      win = {
        border = "single",
      },
    },
  },
}
