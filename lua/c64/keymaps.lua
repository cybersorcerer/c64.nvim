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
    -- Assemble and upload to C64 Ultimate
    vim.keymap.set("n", "<leader>kuR", function()
      require("c64.c64u").assemble_and_run(config)
    end, { desc = "C64U: Assemble and run", silent = true })

    -- Upload current PRG to C64 Ultimate and run
    vim.keymap.set("n", "<leader>kur", function()
      local prg_file = vim.fn.expand("%:p:r") .. ".prg"
      require("c64.c64u").upload_and_run(config, prg_file)
    end, { desc = "C64U: Upload and run PRG", silent = true })

    -- Upload current PRG without running
    vim.keymap.set("n", "<leader>kuu", function()
      local prg_file = vim.fn.expand("%:p:r") .. ".prg"
      require("c64.c64u").upload_only(config, prg_file)
    end, { desc = "C64U: Upload PRG only", silent = true })

    -- Reset C64 Ultimate
    vim.keymap.set("n", "<leader>kux", function()
      require("c64.c64u").reset(config)
    end, { desc = "C64U: Reset machine", silent = true })

    -- Get C64 Ultimate version
    vim.keymap.set("n", "<leader>kuv", function()
      require("c64.c64u").get_version(config)
    end, { desc = "C64U: Get API version", silent = true })

    -- List drives
    vim.keymap.set("n", "<leader>kul", function()
      require("c64.c64u").list_drives(config)
    end, { desc = "C64U: List drives", silent = true })

    -- Mount disk image
    vim.keymap.set("n", "<leader>kum", function()
      local image = vim.fn.input("Disk image path: ", "", "file")
      if image ~= "" then
        local drive = vim.fn.input("Drive number (8-11): ", "8")
        local mode = vim.fn.input("Mount mode (readonly/readwrite/unlinked): ", "readonly")
        require("c64.c64u").mount_disk(config, drive, image, mode)
      end
    end, { desc = "C64U: Mount disk image", silent = true })

    -- Unmount disk
    vim.keymap.set("n", "<leader>kuU", function()
      local drive = vim.fn.input("Drive number to unmount (8-11): ", "8")
      require("c64.c64u").unmount_disk(config, drive)
    end, { desc = "C64U: Unmount disk", silent = true })
  end
end

return M
