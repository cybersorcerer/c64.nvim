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
      { "<leader>ku", group = "C64 Ultimate" },
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

    vim.keymap.set("n", "<leader>cs", function()
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

  -- C64 Ultimate integration (if enabled)
  if config.c64u and config.c64u.enabled then
    -- Assemble and upload to C64 Ultimate (Telescope)
    vim.keymap.set("n", "<leader>kuR", function()
      require("telescope").extensions.c64u.assemble_and_upload()
    end, { desc = "C64U: Assemble and upload", silent = true })

    -- Upload PRG file picker (Telescope)
    vim.keymap.set("n", "<leader>kuu", function()
      require("telescope").extensions.c64u.upload_prg()
    end, { desc = "C64U: Upload PRG file", silent = true })

    -- Drives manager (Telescope)
    vim.keymap.set("n", "<leader>kud", function()
      require("telescope").extensions.c64u.drives()
    end, { desc = "C64U: Manage drives", silent = true })

    -- Machine control (Telescope)
    vim.keymap.set("n", "<leader>kux", function()
      require("telescope").extensions.c64u.machine()
    end, { desc = "C64U: Machine control", silent = true })

    -- Get C64 Ultimate version
    vim.keymap.set("n", "<leader>kuv", function()
      require("c64.c64u").get_version(config)
    end, { desc = "C64U: Get API version", silent = true })

    -- Create disk image
    vim.keymap.set("n", "<leader>kuc", function()
      require("c64.c64u").create_disk_image(config)
    end, { desc = "C64U: Create disk image", silent = true })

    -- Create directory on partition
    vim.keymap.set("n", "<leader>kum", function()
      require("c64.c64u").create_partition_directory(config)
    end, { desc = "C64U: Create directory on partition", silent = true })
  end
end

return M
