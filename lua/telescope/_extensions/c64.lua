-- Telescope extension for c64.nvim

local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  error("This extension requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

local M = {}

-- Load C64 memory data from JSON file
local function load_c64_memory_json()
  local json_path = vim.fn.expand("~/.config/kickass_ls/C64memory.json")

  if vim.fn.filereadable(json_path) ~= 1 then
    vim.notify("C64memory.json not found at: " .. json_path, vim.log.levels.WARN)
    return nil
  end

  local file = io.open(json_path, "r")
  if not file then
    vim.notify("Could not open C64memory.json", vim.log.levels.ERROR)
    return nil
  end

  local content = file:read("*all")
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    vim.notify("Failed to parse C64memory.json: " .. tostring(data), vim.log.levels.ERROR)
    return nil
  end

  return data
end

-- Path to c64ref.md (relative to plugin root)
local function get_ref_path()
  -- Try multiple strategies to find the plugin root
  local strategies = {
    -- Strategy 1: Use runtimepath to find c64.nvim
    function()
      for _, path in ipairs(vim.api.nvim_list_runtime_paths()) do
        if path:match("c64%.nvim") then
          return path .. "/c64ref/c64ref.md"
        end
      end
      return nil
    end,
    -- Strategy 2: Relative to this file
    function()
      local this_file = debug.getinfo(1).source:sub(2)
      local plugin_dir = vim.fn.fnamemodify(this_file, ":h:h:h:h")
      return plugin_dir .. "/c64ref/c64ref.md"
    end,
  }

  for _, strategy in ipairs(strategies) do
    local ref_path = strategy()
    if ref_path and vim.fn.filereadable(ref_path) == 1 then
      return ref_path
    end
  end

  -- Fallback error
  vim.notify("C64 reference manual not found. Check c64ref/c64ref.md exists in plugin directory.", vim.log.levels.ERROR)
  return nil
end

-- Show C64 memory map reference
local function c64_memory_map(opts)
  opts = opts or {}

  -- Load data from JSON file
  local json_data = load_c64_memory_json()
  if not json_data or not json_data.memoryMap or not json_data.memoryMap.regions then
    vim.notify("Failed to load C64 memory data", vim.log.levels.ERROR)
    return
  end

  -- Convert JSON regions to sorted table
  local memory_map = {}
  for address_hex, data in pairs(json_data.memoryMap.regions) do
    -- Convert hex address to uppercase format like $D000
    local addr_num = tonumber(address_hex)
    local addr_formatted = string.format("$%04X", addr_num)

    table.insert(memory_map, {
      address = addr_formatted,
      name = data.name,
      category = data.category,
      description = data.description,
      access = data.access or "",
      tips = data.tips or {},
      examples = data.examples or {},
      bitFields = data.bitFields or {},
    })
  end

  -- Sort by address
  table.sort(memory_map, function(a, b)
    return a.address < b.address
  end)

  pickers
    .new(opts, {
      prompt_title = "C64 Memory Map",
      finder = finders.new_table({
        results = memory_map,
        entry_maker = function(entry)
          return {
            value = entry,
            display = string.format("%-8s %-12s [%s] %s", entry.address, entry.category, entry.access, entry.name),
            ordinal = entry.address .. " " .. entry.name .. " " .. entry.description .. " " .. entry.category,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = previewers.new_buffer_previewer({
        title = "Details",
        define_preview = function(self, entry)
          local lines = {}
          local e = entry.value

          -- Header
          table.insert(lines, e.name)
          table.insert(lines, string.rep("=", 80))
          table.insert(lines, "")
          table.insert(lines, "Address:     " .. e.address)
          table.insert(lines, "Category:    " .. e.category)
          table.insert(lines, "Access:      " .. e.access)
          table.insert(lines, "")
          table.insert(lines, "Description:")
          table.insert(lines, "  " .. e.description)

          -- Bit fields
          if e.bitFields and next(e.bitFields) then
            table.insert(lines, "")
            table.insert(lines, "Bit Fields:")
            for bit, desc in pairs(e.bitFields) do
              table.insert(lines, "  " .. bit .. ": " .. desc)
            end
          end

          -- Examples
          if e.examples and #e.examples > 0 then
            table.insert(lines, "")
            table.insert(lines, "Examples:")
            for _, example in ipairs(e.examples) do
              table.insert(lines, "  " .. example)
            end
          end

          -- Tips
          if e.tips and #e.tips > 0 then
            table.insert(lines, "")
            table.insert(lines, "Tips:")
            for _, tip in ipairs(e.tips) do
              table.insert(lines, "  • " .. tip)
            end
          end

          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
          vim.bo[self.state.bufnr].filetype = "markdown"
        end,
      }),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          -- Browse only - do nothing on selection
        end)
        return true
      end,
    })
    :find()
end

-- Show common C64 registers/constants (filtered by category)
local function c64_registers(opts)
  opts = opts or {}

  -- Load data from JSON file
  local json_data = load_c64_memory_json()
  if not json_data or not json_data.memoryMap or not json_data.memoryMap.regions then
    vim.notify("Failed to load C64 memory data", vim.log.levels.ERROR)
    return
  end

  -- Convert JSON regions to table and filter for registers only
  local registers = {}
  for address_hex, data in pairs(json_data.memoryMap.regions) do
    -- Only include actual hardware registers (not RAM regions)
    if data.type == "register" then
      local addr_num = tonumber(address_hex)
      local addr_formatted = string.format("$%04X", addr_num)

      table.insert(registers, {
        address = addr_formatted,
        name = data.name,
        category = data.category,
        description = data.description,
        access = data.access or "",
        tips = data.tips or {},
        examples = data.examples or {},
        bitFields = data.bitFields or {},
      })
    end
  end

  -- Sort by address
  table.sort(registers, function(a, b)
    return a.address < b.address
  end)

  pickers
    .new(opts, {
      prompt_title = "C64 Hardware Registers",
      finder = finders.new_table({
        results = registers,
        entry_maker = function(entry)
          return {
            value = entry,
            display = string.format("%-8s %-12s [%s] %s", entry.address, entry.category, entry.access, entry.name),
            ordinal = entry.address .. " " .. entry.name .. " " .. entry.description .. " " .. entry.category,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = previewers.new_buffer_previewer({
        title = "Details",
        define_preview = function(self, entry)
          local lines = {}
          local e = entry.value

          -- Header
          table.insert(lines, e.name)
          table.insert(lines, string.rep("=", 80))
          table.insert(lines, "")
          table.insert(lines, "Address:     " .. e.address)
          table.insert(lines, "Category:    " .. e.category)
          table.insert(lines, "Access:      " .. e.access)
          table.insert(lines, "")
          table.insert(lines, "Description:")
          table.insert(lines, "  " .. e.description)

          -- Bit fields
          if e.bitFields and next(e.bitFields) then
            table.insert(lines, "")
            table.insert(lines, "Bit Fields:")
            for bit, desc in pairs(e.bitFields) do
              table.insert(lines, "  " .. bit .. ": " .. desc)
            end
          end

          -- Examples
          if e.examples and #e.examples > 0 then
            table.insert(lines, "")
            table.insert(lines, "Examples:")
            for _, example in ipairs(e.examples) do
              table.insert(lines, "  " .. example)
            end
          end

          -- Tips
          if e.tips and #e.tips > 0 then
            table.insert(lines, "")
            table.insert(lines, "Tips:")
            for _, tip in ipairs(e.tips) do
              table.insert(lines, "  • " .. tip)
            end
          end

          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
          vim.bo[self.state.bufnr].filetype = "markdown"
        end,
      }),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          -- Browse only - do nothing on selection
        end)
        return true
      end,
    })
    :find()
end

-- Search C64 Reference Manual (shows TOC chapters only)
local function c64_reference(opts)
  opts = opts or {}

  local c64ref = require("c64.c64ref")
  local ref_path = get_ref_path()

  -- Parse the reference manual from Table of Contents
  local chapters, err = c64ref.parse_toc_chapters(ref_path)

  if err then
    vim.notify("Error loading C64 reference: " .. err, vim.log.levels.ERROR)
    return
  end

  if not chapters or #chapters == 0 then
    vim.notify("No chapters found in C64 reference manual", vim.log.levels.WARN)
    return
  end

  pickers
    .new(opts, {
      prompt_title = "C64 Reference Manual",
      finder = finders.new_table({
        results = chapters,
        entry_maker = function(entry)
          -- Clean title for display (remove ## prefix)
          local display_title = entry.title:gsub("^#+%s*", "")

          return {
            value = entry,
            display = display_title,
            ordinal = display_title,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = previewers.new_buffer_previewer({
        title = "Preview",
        define_preview = function(self, entry)
          local lines = {}

          -- Show first 50 lines of chapter as preview
          local line_count = 0
          for line in entry.value.content:gmatch("[^\r\n]+") do
            table.insert(lines, line)
            line_count = line_count + 1
            if line_count >= 50 then
              table.insert(lines, "")
              table.insert(lines, "... (press Enter to view full chapter)")
              break
            end
          end

          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
          vim.bo[self.state.bufnr].filetype = "markdown"
        end,
      }),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          -- Show complete chapter in vertical split
          c64ref.show_section(selection.value)
        end)
        return true
      end,
    })
    :find()
end

-- Export extension
return telescope.register_extension({
  exports = {
    memory_map = c64_memory_map,
    registers = c64_registers,
    reference = c64_reference,
  },
})
