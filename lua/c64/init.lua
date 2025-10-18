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
    show_diagnostics = "<leader>d",
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
end

return M
