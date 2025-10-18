-- Filetype detection for Kick Assembler files
-- Multi-level detection strategy:
-- 1. Check for Kick Assembler-specific directives
-- 2. Check for project marker files (.kickass, kickass.cfg, etc.)
-- 3. Check for C64-specific patterns as hints
-- 4. Manual activation via :C64Enable command

local function find_project_marker()
  -- Look for Kick Assembler project marker files
  local markers = { ".kickass", "kickass.cfg", ".kickassembler" }
  local current_dir = vim.fn.expand("%:p:h")

  -- Search up the directory tree (max 5 levels)
  for _ = 1, 5 do
    for _, marker in ipairs(markers) do
      local marker_path = current_dir .. "/" .. marker
      if vim.fn.filereadable(marker_path) == 1 or vim.fn.isdirectory(marker_path) == 1 then
        return true
      end
    end

    -- Move up one directory
    local parent = vim.fn.fnamemodify(current_dir, ":h")
    if parent == current_dir then
      break -- Reached root
    end
    current_dir = parent
  end

  return false
end

local function has_kickass_directives()
  -- Get first 100 lines of the file for detection
  local lines = vim.api.nvim_buf_get_lines(0, 0, 100, false)

  -- Kick Assembler specific patterns
  local kickass_patterns = {
    "^%s*%.import",           -- .import directive
    "^%s*%.importonce",       -- .importonce directive
    "^%s*%.namespace",        -- .namespace directive
    "^%s*%.filenamespace",    -- .filenamespace directive
    "^%s*%.macro%s",          -- .macro definition
    "^%s*%.pseudocommand",    -- .pseudocommand definition
    "^%s*%.function%s",       -- .function definition
    "^%s*%.return%s",         -- .return statement
    "^%s*%.eval",             -- .eval directive
    "^%s*%.print",            -- .print directive
    "^%s*%.assert",           -- .assert directive
    "^%s*%.const%s",          -- .const definition
    "^%s*%.var%s",            -- .var definition
    "^%s*%.enum%s",           -- .enum definition
    "^%s*%.struct%s",         -- .struct definition
    "^%s*%.encoding",         -- .encoding directive
    "^%s*%.segment",          -- .segment directive
    "^%s*%.segmentdef",       -- .segmentdef directive
    "^%s*%.plugin%s",         -- .plugin directive
    "%.toHexString%(",        -- Kick Assembler built-in function
    "%.toBinaryString%(",     -- Kick Assembler built-in function
    "CmdArgument%(",          -- Kick Assembler built-in function
    "LoadBinary%(",           -- Kick Assembler built-in function
    "LoadSid%(",              -- Kick Assembler built-in function
    "LoadPicture%(",          -- Kick Assembler built-in function
  }

  -- Check each line for Kick Assembler patterns
  for _, line in ipairs(lines) do
    for _, pattern in ipairs(kickass_patterns) do
      if line:match(pattern) then
        return true
      end
    end
  end

  return false
end

local function has_c64_patterns()
  -- Get first 100 lines for C64-specific pattern detection
  local lines = vim.api.nvim_buf_get_lines(0, 0, 100, false)

  -- C64-specific memory addresses and register patterns (as hints, not definitive)
  local c64_patterns = {
    "%$[dD]0[0-7][0-9a-fA-F]",  -- VIC-II registers ($D000-$D7FF)
    "%$[dD][4-7][0-9a-fA-F][0-9a-fA-F]", -- SID, Color RAM, CIA
    "%$0400",                    -- Screen memory
    "%$[dD]020",                 -- Border color
    "%$[dD]021",                 -- Background color
    "CHROUT",                    -- Kernal routine
    "GETIN",                     -- Kernal routine
    "PLOT",                      -- Kernal routine
  }

  local c64_count = 0

  for _, line in ipairs(lines) do
    for _, pattern in ipairs(c64_patterns) do
      if line:match(pattern) then
        c64_count = c64_count + 1
        if c64_count >= 2 then -- At least 2 C64-specific references
          return true
        end
      end
    end
  end

  return false
end

local function detect_kickass()
  -- Level 1: Check for explicit Kick Assembler directives (most reliable)
  if has_kickass_directives() then
    return true, "kickass directives found"
  end

  -- Level 2: Check for project marker file
  if find_project_marker() then
    return true, "project marker found"
  end

  -- Level 3: Check for C64-specific patterns (hint, not definitive)
  if has_c64_patterns() then
    return true, "C64 patterns detected"
  end

  return false, "no kickass indicators found"
end

-- Set up filetype detection
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.asm", "*.s", "*.inc" },
  callback = function()
    -- Only set filetype if it's not already set or if it's a generic asm
    if vim.bo.filetype == "" or vim.bo.filetype == "asm" then
      local is_kickass, reason = detect_kickass()
      if is_kickass then
        vim.bo.filetype = "kickass"
        -- Optional: notify user why it was detected (can be disabled)
        -- vim.notify("Kick Assembler detected: " .. reason, vim.log.levels.DEBUG)
      end
    end
  end,
})
