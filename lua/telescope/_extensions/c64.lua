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

local M = {}

-- Show C64 memory map reference
local function c64_memory_map(opts)
  opts = opts or {}

  local memory_map = {
    { address = "$0000-$00FF", description = "Zero Page (Fast memory access)" },
    { address = "$0100-$01FF", description = "Stack" },
    { address = "$0200-$03FF", description = "BASIC and Kernal working storage" },
    { address = "$0400-$07FF", description = "Screen memory (default)" },
    { address = "$0800-$9FFF", description = "BASIC program area" },
    { address = "$A000-$BFFF", description = "BASIC ROM" },
    { address = "$C000-$CFFF", description = "RAM (free)" },
    { address = "$D000-$D3FF", description = "VIC-II (Video Interface Controller)" },
    { address = "$D400-$D7FF", description = "SID (Sound Interface Device)" },
    { address = "$D800-$DBFF", description = "Color RAM" },
    { address = "$DC00-$DCFF", description = "CIA 1 (Complex Interface Adapter)" },
    { address = "$DD00-$DDFF", description = "CIA 2" },
    { address = "$DE00-$DFFF", description = "I/O Area 1" },
    { address = "$E000-$FFFF", description = "Kernal ROM" },
  }

  pickers
    .new(opts, {
      prompt_title = "C64 Memory Map",
      finder = finders.new_table({
        results = memory_map,
        entry_maker = function(entry)
          return {
            value = entry,
            display = string.format("%-15s %s", entry.address, entry.description),
            ordinal = entry.address .. " " .. entry.description,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          -- Insert the address at cursor position
          vim.api.nvim_put({ selection.value.address }, "c", true, true)
        end)
        return true
      end,
    })
    :find()
end

-- Show common C64 registers/constants
local function c64_registers(opts)
  opts = opts or {}

  local registers = {
    { name = "SCREEN", address = "$0400", description = "Default screen memory" },
    { name = "BORDER", address = "$D020", description = "Border color" },
    { name = "BACKGROUND", address = "$D021", description = "Background color" },
    { name = "SPRITE0X", address = "$D000", description = "Sprite 0 X position" },
    { name = "SPRITE0Y", address = "$D001", description = "Sprite 0 Y position" },
    { name = "RASTER", address = "$D012", description = "Raster line register" },
    { name = "VICBANK", address = "$DD00", description = "VIC bank selection" },
    { name = "SIDV1FREQ", address = "$D400", description = "SID Voice 1 frequency" },
    { name = "SIDV1CTRL", address = "$D404", description = "SID Voice 1 control" },
  }

  pickers
    .new(opts, {
      prompt_title = "C64 Registers & Constants",
      finder = finders.new_table({
        results = registers,
        entry_maker = function(entry)
          return {
            value = entry,
            display = string.format("%-12s %-8s %s", entry.name, entry.address, entry.description),
            ordinal = entry.name .. " " .. entry.address .. " " .. entry.description,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          -- Insert the constant name at cursor position
          vim.api.nvim_put({ selection.value.name }, "c", true, true)
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
  },
})
