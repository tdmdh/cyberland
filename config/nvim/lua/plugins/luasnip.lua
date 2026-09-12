return {
  "L3MON4D3/LuaSnip",
  config = function(_, opts)
    require("luasnip").setup(opts)
    -- This exact line is required for Neovim to read your go.lua file
    require("luasnip.loaders.from_lua").lazy_load({
      paths = { vim.fn.stdpath("config") .. "/snippets" },
    })
  end,
}
