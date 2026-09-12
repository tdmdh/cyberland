return {
  {
    dir = vim.fn.stdpath("config"),
    name = "tokyo",
    lazy = false,
    priority = 1000,
    opts = {
      transparent = true, -- Inherit kitty's translucent ground
    },
    config = function(_, opts)
      require("tokyo").setup(opts)
      vim.cmd.colorscheme("tokyo")
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyo",
    },
  },
}
