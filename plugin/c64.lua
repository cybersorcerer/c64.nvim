-- c64.nvim plugin initialization
-- This file is automatically loaded by Neovim

-- Prevent loading twice
if vim.g.loaded_c64_nvim then
  return
end
vim.g.loaded_c64_nvim = true

-- Define user commands
vim.api.nvim_create_user_command("C64Assemble", function()
  require("c64.assembler").assemble(require("c64").config)
end, { desc = "Assemble current file with Kick Assembler" })

vim.api.nvim_create_user_command("C64Run", function()
  require("c64.vice").run(require("c64").config)
end, { desc = "Run current program in VICE emulator" })

-- Manual activation command for when auto-detection doesn't work
vim.api.nvim_create_user_command("C64Enable", function()
  vim.bo.filetype = "kickass"
  vim.notify("c64.nvim enabled for current buffer", vim.log.levels.INFO)
end, { desc = "Manually enable c64.nvim for current buffer" })

-- Create a project marker file in current directory
vim.api.nvim_create_user_command("C64CreateMarker", function()
  local marker_file = vim.fn.getcwd() .. "/.kickass"
  local file = io.open(marker_file, "w")
  if file then
    file:write("# Kick Assembler project marker\n")
    file:write("# This file enables automatic c64.nvim detection for all .asm files in this directory\n")
    file:close()
    vim.notify("Created .kickass marker file in " .. vim.fn.getcwd(), vim.log.levels.INFO)
  else
    vim.notify("Failed to create .kickass marker file", vim.log.levels.ERROR)
  end
end, { desc = "Create .kickass marker file in current directory" })
