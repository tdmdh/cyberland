local M = {}

function M.get_theme()
  local p = require("tokyo.palette").get({ transparent = false })

  return {
    normal = {
      a = { fg = p.on_accent, bg = p.accent, gui = "bold" },
      b = { fg = p.fg, bg = p.bg_layer2 },
      c = { fg = p.fg_dim, bg = p.bg_layer1 },
    },
    insert = {
      a = { fg = p.on_accent, bg = p.ok, gui = "bold" },
      b = { fg = p.fg, bg = p.bg_layer2 },
      c = { fg = p.fg_dim, bg = p.bg_layer1 },
    },
    visual = {
      a = { fg = p.on_accent, bg = p.warn, gui = "bold" },
      b = { fg = p.fg, bg = p.bg_layer2 },
      c = { fg = p.fg_dim, bg = p.bg_layer1 },
    },
    replace = {
      a = { fg = p.on_accent, bg = p.alert, gui = "bold" },
      b = { fg = p.fg, bg = p.bg_layer2 },
      c = { fg = p.fg_dim, bg = p.bg_layer1 },
    },
    command = {
      a = { fg = p.on_accent, bg = p.accent2, gui = "bold" },
      b = { fg = p.fg, bg = p.bg_layer2 },
      c = { fg = p.fg_dim, bg = p.bg_layer1 },
    },
    inactive = {
      a = { fg = p.dim, bg = p.bg_layer1, gui = "bold" },
      b = { fg = p.dim, bg = p.bg_layer1 },
      c = { fg = p.dim, bg = p.bg_layer1 },
    },
  }
end

return M
