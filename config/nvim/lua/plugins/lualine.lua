return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  opts = function(_, opts)
    local tokyo_lualine = require("tokyo.lualine")

    local mode_map = {
      ["NORMAL"] = "通常 NORMAL",
      ["O-PENDING"] = "待機 PENDING",
      ["INSERT"] = "挿入 INSERT",
      ["VISUAL"] = "選択 VISUAL",
      ["V-LINE"] = "行選択 V-LINE",
      ["V-BLOCK"] = "塊選択 V-BLOCK",
      ["SELECT"] = "選択 SELECT",
      ["S-LINE"] = "行選択 S-LINE",
      ["S-BLOCK"] = "塊選択 S-BLOCK",
      ["REPLACE"] = "置換 REPLACE",
      ["V-REPLACE"] = "置換 V-REPLACE",
      ["COMMAND"] = "指令 COMMAND",
      ["EX"] = "指令 EX",
      ["MORE"] = "継続 MORE",
      ["CONFIRM"] = "確認 CONFIRM",
      ["SHELL"] = "殻 SHELL",
      ["TERMINAL"] = "端末 TERMINAL",
    }

    opts.options = opts.options or {}
    opts.options.theme = tokyo_lualine.get_theme()
    opts.options.section_separators = { left = "", right = "" }
    opts.options.component_separators = { left = "│", right = "│" }
    opts.options.globalstatus = true

    opts.sections = opts.sections or {}
    opts.sections.lualine_a = {
      {
        "mode",
        fmt = function(str)
          return mode_map[str] or str
        end,
        padding = { left = 1, right = 1 },
      },
    }

    opts.sections.lualine_b = {
      {
        "branch",
        icon = "",
        padding = { left = 1, right = 1 },
      },
      {
        "diff",
        symbols = {
          added = " ",
          modified = " ",
          removed = " ",
        },
      },
    }

    opts.sections.lualine_c = {
      {
        "diagnostics",
        symbols = {
          error = " ",
          warn = " ",
          info = " ",
          hint = " ",
        },
      },
      { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
      { "filename", path = 1, symbols = { modified = " ●", readonly = " " } },
    }

    opts.sections.lualine_x = {
      -- Snacks / Lazy status if active
      {
        function()
          return require("noice").api.status.command.get()
        end,
        cond = function()
          return package.loaded["noice"] and require("noice").api.status.command.has()
        end,
        color = function()
          return { fg = require("tokyo.palette").get().accent }
        end,
      },
    }

    opts.sections.lualine_y = {
      { "encoding" },
      { "fileformat" },
    }

    opts.sections.lualine_z = {
      {
        function()
          return string.format("LN:%d COL:%d", vim.fn.line("."), vim.fn.col("."))
        end,
        padding = { left = 1, right = 1 },
      },
      { "progress" },
    }

    return opts
  end,
}
