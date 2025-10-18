-- C64 Reference Manual Parser and Search

local M = {}

-- Parse the c64ref.md file into sections
function M.parse_sections(file_path)
  local sections = {}
  local file = io.open(file_path, "r")

  if not file then
    return nil, "Could not open reference file: " .. file_path
  end

  local current_title = nil
  local content_buffer = {}

  for line in file:lines() do
    -- Check if line is a header (starts with #)
    if line:match("^#+%s+") then
      -- Save previous section if exists
      if current_title then
        table.insert(sections, {
          title = current_title,
          content = table.concat(content_buffer, "\n"):gsub("^%s*(.-)%s*$", "%1"),
          level = #current_title:match("^#+"),
        })
      end

      current_title = line
      content_buffer = {}
    elseif current_title then
      table.insert(content_buffer, line)
    end
  end

  -- Add last section
  if current_title then
    table.insert(sections, {
      title = current_title,
      content = table.concat(content_buffer, "\n"):gsub("^%s*(.-)%s*$", "%1"),
      level = #current_title:match("^#+"),
    })
  end

  file:close()
  return sections, nil
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
  -- Prepare content
  local lines = {}
  table.insert(lines, section.title)
  table.insert(lines, string.rep("=", 80))
  table.insert(lines, "")

  for line in section.content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
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
