-- Keymap configuration

local M = {}

function M.setup(config)
  -- which-key.nvim integration (optional, auto-detected if installed)
  local wk_ok, wk = pcall(require, "which-key")
  if wk_ok then
    wk.add({
      { "<leader>k", group = "C64 Assembler" },
      { "<leader>d", group = "Diagnostics" },
      { "<leader>c", group = "C64 Reference" },
    })
  end

  -- Assemble current file
  vim.keymap.set("n", config.keymaps.assemble, function()
    require("c64.assembler").assemble(config)
  end, { desc = "Assemble with Kick Assembler", silent = true })

  -- Run in VICE emulator
  vim.keymap.set("n", config.keymaps.run_vice, function()
    require("c64.vice").run(config)
  end, { desc = "Run in VICE emulator", silent = true })

  -- Debug in VICE emulator with monitor and symbols
  vim.keymap.set("n", config.keymaps.debug_vice, function()
    require("c64.vice").debug(config)
  end, { desc = "Debug in VICE with monitor", silent = true })

  -- Toggle VICE monitor (floating terminal)
  vim.keymap.set("n", "<leader>km", function()
    require("c64.vice").toggle_monitor(config)
  end, { desc = "Toggle VICE monitor (floating)", silent = true })

  -- Focus VICE monitor and enter insert mode
  vim.keymap.set("n", "<leader>ki", function()
    require("c64.vice").focus_monitor()
  end, { desc = "Focus VICE monitor and enter insert", silent = true })

  -- Show line diagnostics
  vim.keymap.set("n", config.keymaps.show_diagnostics, function()
    vim.diagnostic.open_float()
  end, { desc = "Show line diagnostics", silent = true })

  -- Diagnostic display mode toggles
  vim.keymap.set("n", "<leader>dv", function()
    require("c64.diagnostic_toggle").enable_virtual_text()
  end, { desc = "Diagnostics: Enable virtual text", silent = true })

  vim.keymap.set("n", "<leader>dl", function()
    require("c64.diagnostic_toggle").enable_virtual_lines()
  end, { desc = "Diagnostics: Enable virtual lines", silent = true })

  vim.keymap.set("n", "<leader>ds", function()
    require("c64.diagnostic_toggle").enable_signs_only()
  end, { desc = "Diagnostics: Signs only", silent = true })

  vim.keymap.set("n", "<leader>dt", function()
    require("c64.diagnostic_toggle").cycle_modes()
  end, { desc = "Diagnostics: Toggle display mode", silent = true })

  -- Telescope integration for diagnostics (if available)
  local telescope_ok, _ = pcall(require, "telescope")
  if telescope_ok then
    vim.keymap.set("n", "<leader>dd", function()
      require("telescope.builtin").diagnostics({ bufnr = 0 })
    end, { desc = "Telescope: Show buffer diagnostics", silent = true })

    vim.keymap.set("n", "<leader>dw", function()
      require("telescope.builtin").diagnostics()
    end, { desc = "Telescope: Show workspace diagnostics", silent = true })

    vim.keymap.set("n", "<leader>ts", function()
      require("telescope.builtin").lsp_document_symbols()
    end, { desc = "Telescope: Show document symbols", silent = true })

    -- C64 Reference Manual search
    vim.keymap.set("n", "<leader>cr", function()
      require("telescope").extensions.c64.reference()
    end, { desc = "C64: Search reference manual", silent = true })

    vim.keymap.set("n", "<leader>cm", function()
      require("telescope").extensions.c64.memory_map()
    end, { desc = "C64: Memory map", silent = true })

    vim.keymap.set("n", "<leader>cR", function()
      require("telescope").extensions.c64.registers()
    end, { desc = "C64: Registers", silent = true })
  end
end

return M
