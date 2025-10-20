-- LSP configuration for kickass_ls
-- Uses native Neovim LSP (vim.lsp.start)

local M = {}

-- On_attach function for kickass_ls specific setup
local function on_attach(_, bufnr)
  -- Set omnifunc for completion (works with nvim-cmp or manual completion)
  vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'
end

-- Find root directory for the LSP
local function find_root_dir(bufnr)
  local root_patterns = { '.git', '.kickass', 'kickass.cfg' }
  local root = vim.fs.root(bufnr, root_patterns)
  return root or vim.fn.getcwd()
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

  -- Setup LSP using native vim.lsp.start() on FileType
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'kickass',
    callback = function(args)
      local bufnr = args.buf
      local root_dir = find_root_dir(bufnr)

      -- Start the LSP client
      local client_id = vim.lsp.start({
        name = 'kickass_ls',
        cmd = { config.kickass_ls_binary },
        root_dir = root_dir,
        settings = config.lsp.settings,
        on_attach = on_attach,
        flags = {
          debounce_text_changes = 150,
        },
      })

      if not client_id then
        vim.notify("Failed to start kickass_ls", vim.log.levels.ERROR)
      end
    end,
  })
end

return M
