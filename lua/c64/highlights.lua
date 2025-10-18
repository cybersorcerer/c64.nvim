-- Kick Assembler LSP Semantic Token Highlighting

local M = {}

function M.setup(config)
  -- Apply highlight groups from configuration
  for group, opts in pairs(config.highlight) do
    vim.api.nvim_set_hl(0, group, opts)
  end
end

return M
