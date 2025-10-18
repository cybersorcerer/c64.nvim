-- Keymap configuration

local M = {}

function M.setup(config)
  -- Assemble current file
  vim.keymap.set("n", config.keymaps.assemble, function()
    require("c64.assembler").assemble(config)
  end, { desc = "Assemble with Kick Assembler", silent = true })

  -- Run in VICE emulator
  vim.keymap.set("n", config.keymaps.run_vice, function()
    require("c64.vice").run(config)
  end, { desc = "Run in VICE emulator", silent = true })

  -- Show line diagnostics
  vim.keymap.set("n", config.keymaps.show_diagnostics, function()
    vim.diagnostic.open_float()
  end, { desc = "Show line diagnostics", silent = true })

  -- Telescope integration for diagnostics (if available)
  local telescope_ok, _ = pcall(require, "telescope")
  if telescope_ok then
    vim.keymap.set("n", "<leader>td", function()
      require("telescope.builtin").diagnostics()
    end, { desc = "Telescope: Show diagnostics", silent = true })

    vim.keymap.set("n", "<leader>ts", function()
      require("telescope.builtin").lsp_document_symbols()
    end, { desc = "Telescope: Show document symbols", silent = true })
  end
end

return M
