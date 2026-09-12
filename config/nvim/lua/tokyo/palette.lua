local M = {}

local function to_hex(c, fallback)
  if not c or c == "" then return fallback end
  if type(c) == "string" and c:sub(1, 1) == "#" then return c end
  if type(c) == "string" then
    local hex = c:match("rgb%((%x+)%)")
    if hex then return "#" .. hex end
  end
  return fallback
end

function M.get(opts)
  opts = opts or {}
  local transparent = opts.transparent ~= false

  -- Load the desktop's canonical tokyo.lua
  local tokyo_path = vim.fn.expand("~/.config/hypr/wallust/tokyo.lua")
  local raw = {}
  local f = loadfile(tokyo_path)
  if f then
    local ok, res = pcall(f)
    if ok and type(res) == "table" then
      raw = res
    end
  end

  -- Wallust secondary ANSI colors if available
  local colors_path = vim.fn.expand("~/.config/hypr/wallust/colors.lua")
  local wal = {}
  local cf = loadfile(colors_path)
  if cf then
    local ok, res = pcall(cf)
    if ok and type(res) == "table" then
      wal = res
    end
  end

  local bg_base = to_hex(raw.windowBackground, "#131313")
  local fg_base = to_hex(raw.primaryText, "#F3E7CE")
  local accent  = to_hex(raw.accentPrimary, "#E28C31")
  local accent2 = to_hex(raw.accentSecondary, "#85531D")
  local dim     = to_hex(raw.secondaryText, "#8A7C60")
  local line    = to_hex(raw.borderPrimary, "#805324")
  local line2   = to_hex(raw.borderSecondary, "#2C2C2D")
  local alert   = to_hex(raw.alert, "#FF4D5A")
  local warn    = to_hex(raw.warn, "#FFB020")
  local ok_col  = to_hex(raw.ok, accent)

  -- Raw color helpers from wallust
  local c_cyan  = to_hex(wal.color11, accent)
  local c_green = to_hex(wal.color12, ok_col)
  local c_blue  = to_hex(wal.color4, accent2)

  return {
    -- Grounds
    bg = transparent and "NONE" or bg_base,
    bg_solid = bg_base,
    bg_layer1 = to_hex(raw.layerBackground1, "#1A1A1B"),
    bg_layer2 = to_hex(raw.layerBackground2, "#212122"),
    bg_layer3 = to_hex(raw.layerBackground3, "#2C2C2D"),

    -- Neutrals
    fg = fg_base,
    fg_dim = to_hex(raw.surfaceText, fg_base),
    dim = dim,
    dim_dark = to_hex(raw.accentDim, "#5A3916"),

    -- Structural lines
    line = line,
    line_dim = line2,

    -- Tokyo signals
    accent = accent,
    accent2 = accent2,
    accent_dim = to_hex(raw.accentDim, "#5A3916"),
    on_accent = to_hex(raw.accentPrimaryText, "#131313"),

    sel_bg = to_hex(raw.selectionBackground, accent),
    sel_fg = to_hex(raw.selectionText, "#131313"),

    -- Semantics (design guarantees: alert=red, warn=amber)
    alert = alert,
    warn = warn,
    ok = ok_col,

    -- Syntax map
    keyword = accent,
    func = accent,
    type = accent2,
    string = (c_green ~= ok_col and c_green) or c_cyan or fg_base,
    number = warn,
    boolean = alert,
    constant = accent,
    comment = dim,
    operator = line,
    delimiter = dim,
    bracket = accent,

    -- Git diffs
    git_add = ok_col,
    git_change = warn,
    git_delete = alert,

    -- Diagnostics
    diag_error = alert,
    diag_warn = warn,
    diag_info = accent,
    diag_hint = dim,
  }
end

return M
