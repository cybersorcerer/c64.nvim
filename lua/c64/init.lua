-- c64.nvim - Neovim plugin for C64 Assembler development
-- Main plugin entry point

local M = {}

-- Default configuration
M.config = {
  kickass_jar_path = vim.fn.expand("/Applications/KickAssembler/kickass.jar"), -- Path to kickass.jar
  vice_binary = "x64", -- VICE emulator binary (should be in PATH)
  kickass_ls_binary = "kickass_ls", -- Language server binary (should be in PATH)

  -- LSP configuration
  lsp = {
    settings = {
      kickass_ls = {
        warnUnusedLabels = false,
        zeroPageOptimization = {
          enabled = true,
          showHints = true,
        },
        branchDistanceValidation = {
          enabled = true,
          showWarnings = true,
        },
        illegalOpcodeDetection = {
          enabled = true,
          showWarnings = true,
        },
        hardwareBugDetection = {
          enabled = true,
          showWarnings = true,
          jmpIndirectBug = true,
        },
        memoryLayoutAnalysis = {
          enabled = true,
          showIOAccess = true,
          showStackWarnings = true,
          showROMWriteWarnings = true,
        },
        magicNumberDetection = {
          enabled = true,
          showHints = true,
          c64Addresses = true,
        },
        deadCodeDetection = {
          enabled = true,
          showWarnings = true,
        },
        styleGuideEnforcement = {
          enabled = true,
          showHints = true,
          upperCaseConstants = true,
          descriptiveLabels = true,
        },
      },
    },
  },

  -- Highlighting configuration
  highlight = {
    ['@lsp.type.mnemonic.kickass'] = { link = 'Function' },
    ['@lsp.type.directive.kickass'] = { link = 'Keyword' },
    ['@lsp.type.preprocessor.kickass'] = { link = 'PreProc' },
    ['@lsp.type.macro.kickass'] = { link = 'Macro' },
    ['@lsp.type.pseudocommand.kickass'] = { link = 'Special' },
    ['@lsp.type.function.kickass'] = { link = 'Function' },
    ['@lsp.type.label.kickass'] = { link = 'Label' },
    ['@lsp.type.number.kickass'] = { fg = '#ff9800' },
    ['@lsp.type.variable.kickass'] = { link = 'Identifier' },
  },

  -- Keybindings
  keymaps = {
    assemble = "<leader>ka",
    run_vice = "<leader>kr",
    debug_vice = "<leader>kd",
    show_diagnostics = "<leader>d",
  },

  -- C64 Ultimate integration
  c64u = {
    enabled = false,  -- Set to true to enable C64 Ultimate integration
    host = nil,       -- C64U hostname/IP (uses c64u CLI config if nil)
    port = nil,       -- HTTP port (uses c64u CLI config if nil)
  },
}

-- Setup function
function M.setup(opts)
  -- Merge user configuration with defaults
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Setup LSP
  require("c64.lsp").setup(M.config)

  -- Setup keymaps
  require("c64.keymaps").setup(M.config)

  -- Setup highlights
  require("c64.highlights").setup(M.config)

  -- Setup diagnostics
  require("c64.diagnostics").setup()

  -- Setup C64 Ultimate filesystem commands (if enabled)
  if M.config.c64u and M.config.c64u.enabled then
    local c64u = require("c64.c64u")

    -- C64ULs - List directory contents
    vim.api.nvim_create_user_command("C64ULs", function(args)
      c64u.fs_list(args.args ~= "" and args.args or "/", M.config)
    end, {
      nargs = "?",
      desc = "List C64 Ultimate directory contents (default: /)"
    })

    -- C64UUpload - Upload file to C64 Ultimate
    vim.api.nvim_create_user_command("C64UUpload", function(args)
      local parts = vim.split(args.args, "%s+")
      local local_file = parts[1]
      local remote_path = parts[2]
      c64u.fs_upload(local_file, remote_path, M.config)
    end, {
      nargs = "+",
      complete = "file",
      desc = "Upload file to C64 Ultimate: C64UUpload <local_file> [remote_path]"
    })

    -- C64UDownload - Download file from C64 Ultimate
    vim.api.nvim_create_user_command("C64UDownload", function(args)
      local parts = vim.split(args.args, "%s+")
      local remote_path = parts[1]
      local local_file = parts[2]
      c64u.fs_download(remote_path, local_file, M.config)
    end, {
      nargs = "+",
      desc = "Download file from C64 Ultimate: C64UDownload <remote_path> [local_file]"
    })

    -- C64UMkdir - Create directory on C64 Ultimate
    vim.api.nvim_create_user_command("C64UMkdir", function(args)
      c64u.fs_mkdir(args.args, M.config)
    end, {
      nargs = 1,
      desc = "Create directory on C64 Ultimate: C64UMkdir <path>"
    })

    -- C64URm - Remove file or directory on C64 Ultimate
    vim.api.nvim_create_user_command("C64URm", function(args)
      c64u.fs_remove(args.args, M.config)
    end, {
      nargs = 1,
      desc = "Remove file/directory on C64 Ultimate (confirms): C64URm <path>"
    })

    -- C64UMv - Move/rename file on C64 Ultimate
    vim.api.nvim_create_user_command("C64UMv", function(args)
      local parts = vim.split(args.args, "%s+")
      if #parts < 2 then
        vim.notify("Usage: C64UMv <source> <dest>", vim.log.levels.ERROR)
        return
      end
      c64u.fs_move(parts[1], parts[2], M.config)
    end, {
      nargs = "+",
      desc = "Move/rename on C64 Ultimate: C64UMv <source> <dest>"
    })

    -- C64UCp - Copy file on C64 Ultimate
    vim.api.nvim_create_user_command("C64UCp", function(args)
      local parts = vim.split(args.args, "%s+")
      if #parts < 2 then
        vim.notify("Usage: C64UCp <source> <dest>", vim.log.levels.ERROR)
        return
      end
      c64u.fs_copy(parts[1], parts[2], M.config)
    end, {
      nargs = "+",
      desc = "Copy file on C64 Ultimate: C64UCp <source> <dest>"
    })

    -- C64UCat - Show file information
    vim.api.nvim_create_user_command("C64UCat", function(args)
      c64u.fs_cat(args.args, M.config)
    end, {
      nargs = 1,
      desc = "Show file info on C64 Ultimate: C64UCat <path>"
    })
  end
end

return M
