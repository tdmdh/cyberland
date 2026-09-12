return {
  {
    "okuuva/auto-save.nvim",
    cmd = "ASToggle", -- optional for lazy loading
    event = { "InsertLeave", "TextChanged" }, -- load on these events
    opts = {
      enabled = true, -- start auto-save when the plugin is loaded
      trigger_events = { -- events that trigger a save
        immediate_save = { "BufLeave", "FocusLost" }, -- save when leaving buffer/focus
        defer_save = { "InsertLeave", "TextChanged" }, -- save after some time
      },
      condition = function(buf)
        local fn = vim.fn
        local utils = require("auto-save.utils.data")

        -- Don't save for special filetypes (like gitcommit or harpoon)
        if utils.not_in(fn.getbufvar(buf, "&filetype"), { "gitcommit", "harpoon" }) then
          return true
        end
        return false
      end,
      write_all_buffers = false, -- write all modified buffers or only the current one
      debounce_delay = 135, -- saves every 135ms
    },
  },
}
