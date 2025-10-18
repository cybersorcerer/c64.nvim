-- LSP configuration for kickass_ls

local M = {}

-- On_attach function for kickass_ls specific setup
-- Note: LSP keybindings should be configured globally via LspAttach autocmd
-- in your main LSP config to avoid conflicts and duplication
local function on_attach(_, bufnr)
  -- Enable completion triggered by <c-x><c-o>
  vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

  -- Kickass-specific LSP setup can go here if needed
  -- For example, custom commands or buffer-local settings
end

function M.setup(config)
  -- Check if kickass_ls is available
  if vim.fn.executable(config.kickass_ls_binary) ~= 1 then
    vim.notify(
      string.format("kickass_ls binary '%s' not found in PATH", config.kickass_ls_binary),
      vim.log.levels.WARN
    )
    return
  end

  -- Try using Neovim 0.11 native LSP configuration first
  local has_native_lsp_config = vim.fn.has('nvim-0.11') == 1

  if has_native_lsp_config then
    -- Use Neovim 0.11+ native vim.lsp.config
    vim.lsp.config('kickass_ls', {
      cmd = { config.kickass_ls_binary },
      filetypes = { 'kickass' },
      root_markers = { '.git', '.kickass', 'kickass.cfg' },
      settings = config.lsp.settings,
      on_attach = on_attach,
    })

    -- Enable the language server for kickass filetype
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'kickass',
      callback = function()
        vim.lsp.enable('kickass_ls')
      end,
    })
  else
    -- Fallback to nvim-lspconfig for older Neovim versions or when using mason
    local ok, lspconfig = pcall(require, "lspconfig")
    if not ok then
      vim.notify("nvim-lspconfig not found. Please install it to use kickass_ls LSP.", vim.log.levels.ERROR)
      return
    end

    -- Register kickass_ls as a custom server if not already registered
    local configs = require('lspconfig.configs')
    if not configs.kickass_ls then
      configs.kickass_ls = {
        default_config = {
          cmd = { config.kickass_ls_binary },
          filetypes = { 'kickass' },
          root_dir = lspconfig.util.root_pattern('.git', '.kickass', 'kickass.cfg'),
          settings = config.lsp.settings or {},
          on_attach = on_attach,
        },
      }
    end

    -- Setup kickass_ls with user configuration
    -- This integrates with mason-lspconfig handlers if they exist
    lspconfig.kickass_ls.setup({
      cmd = { config.kickass_ls_binary },
      settings = config.lsp.settings,
      on_attach = on_attach,
      flags = {
        debounce_text_changes = 150,
      },
    })
  end
end

return M
