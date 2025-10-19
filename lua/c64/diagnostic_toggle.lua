-- Diagnostic display mode toggling

local M = {}

-- Current diagnostic mode
local current_mode = "virtual_text" -- default mode

-- Custom diagnostic signs with Nerd Font icons (shared with diagnostics.lua)
local signs = {
  Error = "󰅚", -- nf-mdi-alert-circle
  Warn = "󰀪",  -- nf-mdi-alert
  Hint = "󰌶",  -- nf-mdi-lightbulb
  Info = "󰋽"   -- nf-mdi-information
}

-- Mode configurations (preserving signs configuration)
local modes = {
  virtual_text = {
    virtual_text = {
      prefix = "●",
      spacing = 2,
    },
    virtual_lines = false,
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = signs.Error,
        [vim.diagnostic.severity.WARN] = signs.Warn,
        [vim.diagnostic.severity.HINT] = signs.Hint,
        [vim.diagnostic.severity.INFO] = signs.Info,
      }
    },
  },
  virtual_lines = {
    virtual_text = false,
    virtual_lines = true,
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = signs.Error,
        [vim.diagnostic.severity.WARN] = signs.Warn,
        [vim.diagnostic.severity.HINT] = signs.Hint,
        [vim.diagnostic.severity.INFO] = signs.Info,
      }
    },
  },
  signs_only = {
    virtual_text = false,
    virtual_lines = false,
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = signs.Error,
        [vim.diagnostic.severity.WARN] = signs.Warn,
        [vim.diagnostic.severity.HINT] = signs.Hint,
        [vim.diagnostic.severity.INFO] = signs.Info,
      }
    },
  },
}

-- Toggle to virtual text mode
function M.enable_virtual_text()
  current_mode = "virtual_text"
  vim.diagnostic.config({
    virtual_text = modes.virtual_text.virtual_text,
    virtual_lines = modes.virtual_text.virtual_lines,
    signs = modes.virtual_text.signs,
  })
  vim.notify("Diagnostics: Virtual text enabled", vim.log.levels.INFO)
end

-- Toggle to virtual lines mode
function M.enable_virtual_lines()
  -- Check if lsp_lines is available
  local ok = pcall(require, "lsp_lines")
  if not ok then
    vim.notify(
      "Virtual lines mode requires lsp_lines plugin.\nInstall: https://git.sr.ht/~whynothugo/lsp_lines.nvim\nFalling back to virtual text mode.",
      vim.log.levels.INFO
    )
    M.enable_virtual_text()
    return
  end

  current_mode = "virtual_lines"
  vim.diagnostic.config({
    virtual_text = modes.virtual_lines.virtual_text,
    virtual_lines = modes.virtual_lines.virtual_lines,
    signs = modes.virtual_lines.signs,
  })
  vim.notify("Diagnostics: Virtual lines enabled", vim.log.levels.INFO)
end

-- Toggle to signs only mode
function M.enable_signs_only()
  current_mode = "signs_only"
  vim.diagnostic.config({
    virtual_text = modes.signs_only.virtual_text,
    virtual_lines = modes.signs_only.virtual_lines,
    signs = modes.signs_only.signs,
  })
  vim.notify("Diagnostics: Signs only (use <leader>d for details)", vim.log.levels.INFO)
end

-- Cycle through modes
function M.cycle_modes()
  if current_mode == "virtual_text" then
    M.enable_virtual_lines()
  elseif current_mode == "virtual_lines" then
    M.enable_signs_only()
  else
    M.enable_virtual_text()
  end
end

-- Get current mode
function M.get_current_mode()
  return current_mode
end

return M
