local M = {}

local fs_event = nil

function M.setup()
  local target = vim.fn.expand("~/.config/hypr/wallust/tokyo.lua")

  -- 1. Filesystem event watcher via libuv
  if vim.uv and vim.uv.new_fs_event then
    local dir = vim.fn.fnamemodify(target, ":h")
    local filename = vim.fn.fnamemodify(target, ":t")

    pcall(function()
      fs_event = vim.uv.new_fs_event()
      if fs_event then
        fs_event:start(dir, {}, function(err, fname, events)
          if not err and fname and (fname == filename or fname == "tokyo.lua") then
            vim.schedule(function()
              require("tokyo").reload()
            end)
          end
        end)
      end
    end)
  end

  -- 2. FocusGained & VimResume fallback
  local group = vim.api.nvim_create_augroup("TokyoAutoSync", { clear = true })
  vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
    group = group,
    callback = function()
      require("tokyo").reload()
    end,
  })

  -- 3. User Commands
  vim.api.nvim_create_user_command("TokyoReload", function()
    require("tokyo").reload()
    local p = require("tokyo.palette").get()
    vim.notify("Tokyo palette reloaded: accent = " .. p.accent .. ", ground = " .. p.bg_solid, vim.log.levels.INFO, {
      title = "Tokyo Design System",
    })
  end, { desc = "Reload Tokyo Cyber-Avionics palette from tokyo.lua" })

  vim.api.nvim_create_user_command("TokyoInfo", function()
    local p = require("tokyo.palette").get()
    local lines = {
      "Tokyo Avionics Telemetry:",
      "  • Ground:   " .. p.bg_solid,
      "  • Layer1:   " .. p.bg_layer1,
      "  • Text:     " .. p.fg,
      "  • Accent:   " .. p.accent,
      "  • Accent2:  " .. p.accent2,
      "  • Border:   " .. p.line,
      "  • Alert:    " .. p.alert,
      "  • Warn:     " .. p.warn,
      "  • Ok:       " .. p.ok,
    }
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, {
      title = "Tokyo Design Tokens",
    })
  end, { desc = "Inspect active Tokyo palette design tokens" })
end

return M
