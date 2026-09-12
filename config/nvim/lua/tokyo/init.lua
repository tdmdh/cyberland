local M = {}

M.options = {
  transparent = true, -- Inherit kitty's translucent ground
}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

function M.load()
  if vim.g.colors_name then
    vim.cmd("hi clear")
  end

  vim.o.termguicolors = true
  vim.g.colors_name = "tokyo"

  local p = require("tokyo.palette").get(M.options)
  require("tokyo.highlights").apply(p)

  -- Initialize filesystem watcher once
  if not M._watcher_started then
    M._watcher_started = true
    require("tokyo.watcher").setup()
  end

end

function M.reload()
  -- Invalidate package caches so fresh tokyo.lua colors are re-read
  package.loaded["tokyo.palette"] = nil
  package.loaded["tokyo.highlights"] = nil
  package.loaded["tokyo.lualine"] = nil
  M.load()

  -- If lualine is already loaded and active, refresh its theme live
  if package.loaded["lualine"] then
    pcall(function()
      require("lualine").setup({
        options = {
          theme = require("tokyo.lualine").get_theme(),
        },
      })
    end)
  end
end

return M
