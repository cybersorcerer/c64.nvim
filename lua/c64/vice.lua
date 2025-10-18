-- VICE Emulator integration

local M = {}

-- Run the current program in VICE
function M.run(config)
  -- Check if VICE is available
  if vim.fn.executable(config.vice_binary) ~= 1 then
    vim.notify(
      string.format("VICE emulator '%s' not found in PATH", config.vice_binary),
      vim.log.levels.ERROR
    )
    return
  end

  -- Find the PRG file (assuming it has the same name as the source file)
  local source_file = vim.fn.expand("%:p")
  local prg_file = vim.fn.expand("%:p:r") .. ".prg"

  -- Check if PRG file exists
  if vim.fn.filereadable(prg_file) ~= 1 then
    vim.notify(
      string.format(
        "PRG file not found: %s\nPlease assemble the program first using <leader>ka",
        vim.fn.fnamemodify(prg_file, ":t")
      ),
      vim.log.levels.WARN
    )
    return
  end

  -- Build VICE command
  local cmd = string.format(
    "%s %s &",
    config.vice_binary,
    vim.fn.shellescape(prg_file)
  )

  vim.notify("Starting VICE with: " .. vim.fn.fnamemodify(prg_file, ":t"), vim.log.levels.INFO)

  -- Execute in background
  vim.fn.jobstart(cmd, {
    detach = true,
    on_exit = function(_, exit_code, _)
      if exit_code ~= 0 then
        vim.notify("VICE exited with error code: " .. exit_code, vim.log.levels.WARN)
      end
    end,
  })
end

return M
