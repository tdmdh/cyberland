return {
  "akinsho/bufferline.nvim",
  event = "VeryLazy",
  opts = function(_, opts)
    local p = require("tokyo.palette").get()

    opts.options = opts.options or {}
    opts.options.separator_style = "thin"
    opts.options.indicator = {
      style = "underline",
    }
    opts.options.modified_icon = "●"
    opts.options.show_buffer_close_icons = false
    opts.options.show_close_icon = false

    opts.highlights = {
      fill = {
        bg = p.bg,
      },
      background = {
        fg = p.dim,
        bg = p.bg_layer1,
      },
      buffer_selected = {
        fg = p.accent,
        bg = p.bg_layer2,
        bold = true,
      },
      buffer_visible = {
        fg = p.fg_dim,
        bg = p.bg_layer1,
      },
      separator = {
        fg = p.line_dim,
        bg = p.bg_layer1,
      },
      separator_selected = {
        fg = p.line,
        bg = p.bg_layer2,
      },
      separator_visible = {
        fg = p.line_dim,
        bg = p.bg_layer1,
      },
      indicator_selected = {
        fg = p.accent,
        bg = p.bg_layer2,
      },
      modified = {
        fg = p.warn,
        bg = p.bg_layer1,
      },
      modified_selected = {
        fg = p.warn,
        bg = p.bg_layer2,
      },
    }

    return opts
  end,
}
