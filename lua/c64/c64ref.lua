-- C64 Reference Manual Parser and Search

local M = {}

-- Parse main chapters only (from docling markdown)
-- Using known line numbers of actual chapters (determined by manual inspection)
function M.parse_toc_chapters(file_path)
  local entries = {}
  local file = io.open(file_path, "r")

  if not file then
    return nil, "Could not open reference file: " .. file_path
  end

  -- Read file into lines
  local lines = {}
  for line in file:lines() do
    table.insert(lines, line)
  end
  file:close()

  -- Define chapter line numbers (1-indexed, as found by grep -n)
  -- These are the REAL chapter headers, not the TOC entries
  local chapter_lines = {
    { title = "INTRODUCTION", line = 195 },
    { title = "BASIC PROGRAMMING RULES", line = 665 },
    { title = "BASIC LANGUAGE VOCABULARY", line = 969 },
    { title = "PROGRAMMING GRAPHICS ON THE COMMODORE 64", line = 2707 },
    { title = "PROGRAMMING SOUND AND MUSIC ON YOUR COMMODORE 64", line = 4893 },
    { title = "BASIC TO MACHINE LANGUAGE", line = 5594 },
    { title = "INPUT/OUTPUT GUIDE", line = 11092 },
    { title = "APPENDICES", line = 11942 },
    { title = "INDEX", line = 15756 },
  }

  for i, chapter_spec in ipairs(chapter_lines) do
    local start_line = chapter_spec.line
    local end_line = #lines

    -- Find where this chapter ends (next chapter starts)
    if i < #chapter_lines then
      end_line = chapter_lines[i + 1].line - 1
    end

    -- Extract lines for this chapter
    local content_lines = {}
    for j = start_line, end_line do
      if lines[j] then
        table.insert(content_lines, lines[j])
      end
    end

    local content = table.concat(content_lines, "\n")

    table.insert(entries, {
      title = chapter_spec.title,
      display = chapter_spec.title,
      content = content,
      has_section = true,
    })
  end

  return entries, nil
end

-- Parse the c64ref.md file into chapters (top-level sections)
function M.parse_chapters(file_path)
  local chapters = {}
  local file = io.open(file_path, "r")

  if not file then
    return nil, "Could not open reference file: " .. file_path
  end

  local current_chapter = nil
  local content_buffer = {}

  for line in file:lines() do
    -- Check if line is a top-level header (starts with ##, which is the top level in this file)
    local level = line:match("^(#+)%s+")

    if level and #level == 2 then
      -- Save previous chapter if exists
      if current_chapter then
        table.insert(chapters, {
          title = current_chapter,
          content = table.concat(content_buffer, "\n"):gsub("^%s*(.-)%s*$", "%1"),
        })
      end

      current_chapter = line
      content_buffer = {}
    elseif current_chapter then
      -- Add all content (including sub-headers) to current chapter
      table.insert(content_buffer, line)
    end
  end

  -- Add last chapter
  if current_chapter then
    table.insert(chapters, {
      title = current_chapter,
      content = table.concat(content_buffer, "\n"):gsub("^%s*(.-)%s*$", "%1"),
    })
  end

  file:close()
  return chapters, nil
end

-- Default to using TOC-based parsing
function M.parse_sections(file_path)
  return M.parse_toc_chapters(file_path)
end

-- Search sections by term
function M.search_sections(sections, search_term)
  if not search_term or search_term == "" then
    return sections
  end

  local results = {}
  local search_lower = search_term:lower()

  for _, section in ipairs(sections) do
    local title_clean = section.title:gsub("^#+%s*", ""):lower()
    if title_clean:find(search_lower, 1, true) or section.content:lower():find(search_lower, 1, true) then
      table.insert(results, section)
    end
  end

  return results
end

-- Static buffer ID for reuse
local ref_buf = nil
local ref_buf_name = "c64-reference"

-- Display section in a vertical split (reuses same buffer)
function M.show_section(section)
  local lines = {}

  -- If this entry has its own section, show it
  if section.has_section then
    table.insert(lines, section.title)
    table.insert(lines, string.rep("=", 80))
    table.insert(lines, "")

    -- Add all content including subsections
    for line in section.content:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
  else
    -- No dedicated section - search for the title in the document
    local search_title = section.title:gsub("^%d+%.%s*", "")
    table.insert(lines, section.title)
    table.insert(lines, string.rep("=", 80))
    table.insert(lines, "")
    table.insert(lines, "Searching for: " .. search_title)
    table.insert(lines, "")

    -- Try to find the title as a heading (### or ####)
    local found = false
    for heading_level = 3, 6 do
      local heading_pattern = "\n" .. string.rep("#", heading_level) .. " " .. search_title:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
      local start_pos = section.content:find(heading_pattern)

      if start_pos then
        -- Found it! Extract content until next heading of same or higher level
        local heading_prefix = ""
        for _ = 1, heading_level do
          heading_prefix = heading_prefix .. "#"
        end
        local next_heading_pattern = "\n" .. heading_prefix .. " "
        local end_pos = section.content:find(next_heading_pattern, start_pos + 10)

        local content_section
        if end_pos then
          content_section = section.content:sub(start_pos + 1, end_pos - 1)
        else
          content_section = section.content:sub(start_pos + 1, start_pos + 2000) -- Show first 2000 chars
        end

        for line in content_section:gmatch("[^\r\n]+") do
          table.insert(lines, line)
        end

        found = true
        break
      end
    end

    if not found then
      table.insert(lines, "Note: This is a subsection reference.")
      table.insert(lines, "Content may be found within its parent chapter.")
    end
  end

  -- Check if buffer exists and is valid
  if ref_buf and vim.api.nvim_buf_is_valid(ref_buf) then
    -- Buffer exists, reuse it
    vim.bo[ref_buf].modifiable = true
    vim.api.nvim_buf_set_lines(ref_buf, 0, -1, false, lines)
    vim.bo[ref_buf].modifiable = false

    -- Update buffer name with new section
    pcall(vim.api.nvim_buf_set_name, ref_buf, ref_buf_name .. ": " .. section.title:gsub("^#+%s*", ""))

    -- Find existing window or create new one
    local wins = vim.fn.win_findbuf(ref_buf)
    if #wins > 0 then
      -- Buffer is already visible, just focus it
      vim.api.nvim_set_current_win(wins[1])
    else
      -- Buffer exists but not visible, open in vsplit
      vim.cmd("vsplit")
      vim.api.nvim_win_set_buf(0, ref_buf)
    end
  else
    -- Create new buffer
    ref_buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_lines(ref_buf, 0, -1, false, lines)
    vim.bo[ref_buf].modifiable = false
    vim.bo[ref_buf].filetype = "markdown"
    vim.bo[ref_buf].bufhidden = "hide" -- Hide instead of wipe to keep buffer alive
    vim.bo[ref_buf].buftype = "nofile"

    -- Set buffer name
    pcall(vim.api.nvim_buf_set_name, ref_buf, ref_buf_name .. ": " .. section.title:gsub("^#+%s*", ""))

    -- Open in vertical split (right side)
    vim.cmd("vsplit")
    vim.api.nvim_win_set_buf(0, ref_buf)

    -- Close on q or ESC (set once when buffer is created)
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ref_buf, silent = true })
    vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = ref_buf, silent = true })
  end

  -- Set window options (always, in case window was just created)
  local win = vim.api.nvim_get_current_win()
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].cursorline = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
end

return M
