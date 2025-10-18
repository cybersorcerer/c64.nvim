-- Kick Assembler integration

local M = {}

-- Parse Kick Assembler output and populate quickfix list
local function parse_kickass_output(output)
  local qf_list = {}

  -- Kick Assembler format:
  -- (filename line:col) Error: message
  -- or
  -- at line X, column Y in filename

  for line in output:gmatch("[^\r\n]+") do
    local filename, lnum, col, msg

    -- Format 1: (filename line:col) Error: message
    -- Example: (/path/to/file.asm 19:1) Error: Too few arguments
    filename, lnum, col, msg = line:match("%(([^%)]+)%s+(%d+):(%d+)%)%s*(.+)")

    if not filename then
      -- Format 2: at line X, column Y in filename
      -- Example: at line 19, column 1 in comprehensive-server-test.asm
      lnum, col, filename = line:match("at line (%d+), column (%d+) in (.+)")
      if lnum then
        -- Use the previous error message if available (stored from format 1)
        msg = "Error at " .. filename
      end
    end

    if not filename then
      -- Format 3: filename:line: message
      filename, lnum, msg = line:match("([^:]+):(%d+):%s*(.+)")
    end

    -- Add to quickfix list if we found a valid error
    if filename and lnum then
      -- Clean up filename (remove leading/trailing whitespace)
      filename = filename:match("^%s*(.-)%s*$")

      -- Expand to full path if it's a relative path
      if not filename:match("^/") then
        filename = vim.fn.getcwd() .. "/" .. filename
      end

      table.insert(qf_list, {
        filename = filename,
        lnum = tonumber(lnum),
        col = tonumber(col) or 1,
        text = msg or line,
        type = "E",
      })
    end
  end

  return qf_list
end

-- Export parser for testing (can be removed later)
M._parse_output = parse_kickass_output

-- Assemble the current file
function M.assemble(config)
  local current_file = vim.fn.expand("%:p")

  -- Check if kickass.jar exists
  if vim.fn.filereadable(config.kickass_jar_path) ~= 1 then
    vim.notify(
      string.format("kickass.jar not found at: %s\nPlease configure the correct path.", config.kickass_jar_path),
      vim.log.levels.ERROR
    )
    return
  end

  -- Check if file is saved
  if vim.bo.modified then
    vim.cmd("write")
  end

  -- Get output directory (same as source file)
  local output_dir = vim.fn.expand("%:p:h")

  -- Build command
  local cmd = string.format(
    "java -jar %s -o %s %s",
    vim.fn.shellescape(config.kickass_jar_path),
    vim.fn.shellescape(output_dir),
    vim.fn.shellescape(current_file)
  )

  vim.notify("Assembling: " .. vim.fn.fnamemodify(current_file, ":t"), vim.log.levels.INFO)

  -- Execute command
  local output = vim.fn.system(cmd)
  -- Note: Kickass Assembler may return exit code 0 even with errors
  -- so we check the output content instead

  -- Check for errors in output, regardless of exit code
  -- Kickass may return exit code 0 even with errors
  local has_errors = output:match("Got %d+ errors") or output:match("Error:")
  local error_count = output:match("Got (%d+) errors")

  if has_errors then
    -- Parse errors from output
    local qf_list = parse_kickass_output(output)

    if #qf_list > 0 then
      vim.fn.setqflist(qf_list, "r")
      local count = error_count or #qf_list

      -- Try to open with Telescope, fallback to quickfix
      local telescope_ok = pcall(require, "telescope.builtin")
      if telescope_ok then
        vim.notify(
          string.format("Assembly failed with %s error(s). Opening Telescope...", count),
          vim.log.levels.ERROR
        )
        -- Defer to let the notification show first
        vim.defer_fn(function()
          require("telescope.builtin").quickfix()
        end, 100)
      else
        -- Fallback to standard quickfix if Telescope not available
        vim.cmd("copen")
        vim.notify(
          string.format("Assembly failed with %s error(s). Check quickfix list.", count),
          vim.log.levels.ERROR
        )
      end
    else
      -- Found error indicator but couldn't parse - show raw output
      vim.notify("Assembly failed (could not parse errors):\n" .. output, vim.log.levels.ERROR)
    end
  elseif output:match("Compiled to") then
    -- Success - found "Compiled to" message
    local prg_file = output:match("Compiled to (.+%.prg)")
    if prg_file then
      vim.notify("Assembly successful! → " .. vim.fn.fnamemodify(prg_file, ":t"), vim.log.levels.INFO)
    else
      vim.notify("Assembly successful!", vim.log.levels.INFO)
    end
    vim.fn.setqflist({}, "r") -- Clear quickfix list
  else
    -- Unclear status - show warning
    vim.notify("Assembly completed (status unclear, check output)", vim.log.levels.WARN)
    print(output) -- Print full output to command line
  end
end

return M
