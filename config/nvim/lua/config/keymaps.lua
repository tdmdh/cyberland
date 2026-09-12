-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
-- Smart Compile and Run with Compilation Timer
vim.keymap.set("n", "<leader>cg", function()
  -- Save the current file
  vim.cmd("write")

  local filetype = vim.bo.filetype
  local file_path = vim.fn.expand("%:p") -- The full file path (e.g., .../main.cpp)
  local dir_path = vim.fn.expand("%:p:h") -- The directory only (e.g., .../go-ollama-stream)
  local file_no_ext = vim.fn.expand("%:p:r") -- The full path without extension
  local cmd = ""

  -- Dynamically choose the command based on file type
  if filetype == "cpp" then
    -- C++ needs the actual file path
    -- shellescape already adds quotes, so we don't use "%s"
    cmd = string.format(
      "time g++ %s -o %s && %s",
      vim.fn.shellescape(file_path),
      vim.fn.shellescape(file_no_ext),
      vim.fn.shellescape(file_no_ext)
    )
  elseif filetype == "go" then
    -- Go: just normal 'cd' (no '!') inside the terminal, then 'go run .'
    cmd = string.format("cd %s && time go run .", vim.fn.shellescape(dir_path))
  else
    vim.notify("No run command configured for filetype: " .. filetype, vim.log.levels.WARN)
    return
  end

  -- Append the pause so the floating window stays open
  cmd = cmd .. ' ; echo ""; echo "[Press Enter to close]"; read'

  -- Launch in the built-in Snacks terminal
  Snacks.terminal(cmd)
end, { desc = "Compile and Run current file" })
