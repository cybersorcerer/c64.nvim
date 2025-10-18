-- Diagnostics configuration for kickass_ls

local M = {}

function M.setup()
  -- Custom diagnostic signs with Nerd Font icons
  local signs = {
    Error = "󰅚", -- nf-mdi-alert-circle
    Warn = "󰀪",  -- nf-mdi-alert
    Hint = "󰌶",  -- nf-mdi-lightbulb
    Info = "󰋽"   -- nf-mdi-information
  }

  for type, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
  end

  -- Force disable virtual_lines plugin if loaded
  local ok, lsp_lines = pcall(require, "lsp_lines")
  if ok then
    lsp_lines.setup()
    vim.diagnostic.config({ virtual_lines = false }, vim.api.nvim_create_namespace("lsp_lines"))
  end

  -- Configure diagnostics with granular control
  vim.diagnostic.config({
    virtual_lines = false, -- Disable virtual lines to reduce clutter
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = signs.Error,
        [vim.diagnostic.severity.WARN] = signs.Warn,
        [vim.diagnostic.severity.HINT] = signs.Hint,
        [vim.diagnostic.severity.INFO] = signs.Info,
      }
    },
    virtual_text = {
      spacing = 2,
      source = "if_many", -- Show source only if multiple sources
      prefix = "●",
      -- Only show inline virtual text for errors and warnings to reduce clutter
      severity = { min = vim.diagnostic.severity.WARN },
      format = function(diagnostic)
        -- Truncate long messages to keep the editor readable
        local max_width = 80
        if #diagnostic.message > max_width then
          return diagnostic.message:sub(1, max_width - 3) .. "..."
        end
        return diagnostic.message
      end,
    },
    float = {
      focusable = false,
      style = "minimal",
      border = "rounded",
      source = "if_many", -- Show source only if multiple sources
      header = "",
      prefix = "",
      -- Show all severities in float window
      severity_sort = true,
    },
    underline = {
      -- Only underline errors to keep it clean
      severity = { min = vim.diagnostic.severity.ERROR },
    },
    update_in_insert = false, -- Don't update diagnostics in insert mode
    severity_sort = true,     -- Sort by severity (errors first)
  })

  -- Configure LSP hover handler with rounded borders
  vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
    vim.lsp.handlers.hover,
    { border = "rounded" }
  )

  -- Configure signature help handler with rounded borders
  vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
    vim.lsp.handlers.signature_help,
    { border = "rounded" }
  )
end

return M
