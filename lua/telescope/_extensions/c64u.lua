-- Telescope extension for C64 Ultimate integration
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

-- Helper function to execute c64u command
local function exec_c64u(args, opts)
  opts = opts or {}
  local cmd = { "c64u" }

  if opts.host then
    table.insert(cmd, "--host")
    table.insert(cmd, opts.host)
  end

  if opts.port then
    table.insert(cmd, "--port")
    table.insert(cmd, tostring(opts.port))
  end

  if opts.json then
    table.insert(cmd, "--json")
  end

  for _, arg in ipairs(args) do
    table.insert(cmd, arg)
  end

  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 then
    return nil, output
  end

  return output, nil
end

-- Check if FTP client is available
local function check_ftp_client()
  local ftp_clients = { "ftp", "ftp.exe" }
  for _, client in ipairs(ftp_clients) do
    if vim.fn.executable(client) == 1 then
      return true, client
    end
  end
  return false, nil
end

-- List FTP directory contents
local function list_ftp_directory(host, port, path)
  local entries = {}

  -- Create FTP script for listing
  local script_file = vim.fn.tempname()

  -- Use dir instead of ls for better compatibility
  -- Quote the path to handle spaces and special characters
  local ftp_commands = string.format([[open %s %s
user anonymous anonymous@
cd "%s"
dir
bye
]], host, port or 21, path)

  vim.fn.writefile(vim.split(ftp_commands, "\n"), script_file)

  -- Execute FTP command and capture output directly
  local cmd = string.format("ftp -n < %s 2>&1", vim.fn.shellescape(script_file))
  local output = vim.fn.system(cmd)

  -- Debug: Check for FTP errors
  if output:match("Failed to change directory") or output:match("No such file or directory") then
    vim.notify(string.format("FTP cd failed for path: %s\nOutput: %s", path, output), vim.log.levels.ERROR)
  end

  -- Parse output line by line
  local lines = vim.split(output, "\n")
  for _, line in ipairs(lines) do
    -- Try multiple parsing patterns

    -- Pattern 1: Unix-style listing (drwxr-xr-x)
    local perms, size, name = line:match("^([drwx%-]+)%s+%d+%s+%S+%s+%S+%s+(%d+)%s+%S+%s+%d+%s+[%d:]+%s+(.+)$")

    if not name then
      -- Pattern 2: Windows-style listing (01-08-26  12:00PM)
      local _, _, size_or_dir, name2 = line:match("^(%d+%-%d+%-%d+)%s+(%d+:%d+[AP]M)%s+(%S+)%s+(.+)$")
      if name2 then
        name = name2
        if size_or_dir == "<DIR>" then
          perms = "d"
          size = "0"
        else
          perms = "-"
          size = size_or_dir
        end
      end
    end

    if name and name ~= "." and name ~= ".." then
      local is_dir = perms and perms:sub(1,1) == "d"
      -- Build path correctly, avoiding double slashes
      local clean_path
      if path == "/" then
        clean_path = "/" .. name
      elseif path:sub(-1) == "/" then
        clean_path = path .. name
      else
        clean_path = path .. "/" .. name
      end

      table.insert(entries, {
        name = name,
        is_dir = is_dir,
        size = tonumber(size) or 0,
        path = clean_path,
      })
    end
  end

  -- Cleanup
  vim.fn.delete(script_file)

  -- Debug info if no entries found
  if #entries == 0 then
    vim.notify("No FTP entries found. Raw output:\n" .. output, vim.log.levels.WARN)
  end

  return entries
end

-- Prompt user to select drive name (a or b)
local function select_drive_name(callback)
  vim.ui.select({ "a", "b" }, {
    prompt = "Select IEC drive:",
  }, function(choice)
    if choice then
      callback(choice)
    end
  end)
end

-- FTP File Browser with nested directory support
M.drives = function(opts)
  opts = opts or {}

  -- Get config from c64 module
  local ok, c64_module = pcall(require, "c64")
  if not ok then
    vim.notify("Failed to load c64 module: " .. tostring(c64_module), vim.log.levels.ERROR)
    return
  end

  local c64_config = c64_module.config

  -- Debug: Check what we actually got
  if not c64_config then
    vim.notify("c64 module config is nil!", vim.log.levels.ERROR)
    return
  end

  if not c64_config.c64u then
    vim.notify("c64u configuration section not found. Please ensure you have set up c64.nvim with c64u enabled.", vim.log.levels.ERROR)
    return
  end

  -- Check if FTP client is available
  local has_ftp = check_ftp_client()
  if not has_ftp then
    vim.notify(
      "FTP client not found in PATH. Please install an FTP client (ftp or ftp.exe) to use this feature.",
      vim.log.levels.ERROR
    )
    return
  end

  -- Get host from config - FTP port is always 21
  local host = c64_config.c64u.host
  local ftp_port = 21

  if not host or host == "" then
    vim.notify(
      "C64 Ultimate host not configured!\n\n" ..
      "Please set c64u.host in your c64.nvim setup configuration.\n\n" ..
      "Example:\n" ..
      "  c64u = {\n" ..
      "    enabled = true,\n" ..
      "    host = \"c64u.homelab.cybersorcerer.org\",\n" ..
      "    port = 80,\n" ..
      "  }\n\n" ..
      "Current value: " .. vim.inspect(host),
      vim.log.levels.ERROR
    )
    return
  end

  local current_path = "/"

  local function show_browser(path)
    current_path = path

    -- Debug: Verify we still have the host
    if not host or host == "" then
      vim.notify("ERROR: Lost host configuration in show_browser! This should not happen.", vim.log.levels.ERROR)
      return
    end

    local entries = list_ftp_directory(host, ftp_port, path)

    -- Add parent directory entry if not at root
    if path ~= "/" then
      table.insert(entries, 1, {
        name = "..",
        is_dir = true,
        size = 0,
        path = path:match("(.*/)[^/]+/?$") or "/",
      })
    end

    pickers.new(opts, {
      prompt_title = "C64U File Browser: " .. path,
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          local icon = entry.is_dir and "📁" or "📄"
          local display = string.format("%s %s", icon, entry.name)

          return {
            value = entry,
            display = display,
            ordinal = entry.name,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      layout_strategy = "center",
      layout_config = {
        width = 0.6,
        height = 0.6,
      },
      attach_mappings = function(prompt_bufnr, map)
        -- Default action: Enter directory or show file info
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          if not selection then
            return
          end

          local entry = selection.value

          if entry.is_dir then
            -- Navigate into directory
            actions.close(prompt_bufnr)
            show_browser(entry.path)
          else
            -- Show file info
            vim.notify(string.format(
              "File: %s\nSize: %d bytes\nPath: %s",
              entry.name,
              entry.size,
              entry.path
            ), vim.log.levels.INFO)
          end
        end)

        -- Create disk image (Ctrl-c)
        map("i", "<C-c>", function()
          actions.close(prompt_bufnr)

          vim.ui.select({ "d64 (35 tracks)", "d64 (40 tracks)", "d71", "d81", "dnp" }, {
            prompt = "Select disk image type:",
          }, function(choice)
            if not choice then
              show_browser(current_path)
              return
            end

            local image_type = choice:match("^(%w+)")

            vim.ui.input({
              prompt = "Disk image filename (without extension): ",
              default = "disk"
            }, function(filename)
              if not filename or filename == "" then
                show_browser(current_path)
                return
              end

              local full_path = current_path .. "/" .. filename .. "." .. image_type

              vim.ui.input({
                prompt = "Disk name/label (max 16 chars): ",
                default = string.upper(filename:sub(1, 16))
              }, function(disk_name)
                if not disk_name or disk_name == "" then
                  disk_name = string.upper(filename:sub(1, 16))
                end

                local cmd_args = { "files", "create-" .. image_type, full_path, "--name", disk_name }

                if choice:match("40 tracks") then
                  table.insert(cmd_args, "--tracks")
                  table.insert(cmd_args, "40")
                elseif image_type == "dnp" then
                  vim.ui.input({
                    prompt = "Number of tracks (1-255): ",
                    default = "35"
                  }, function(tracks)
                    if tracks and tracks ~= "" then
                      table.insert(cmd_args, "--tracks")
                      table.insert(cmd_args, tracks)

                      local _, err = exec_c64u(cmd_args, c64_config.c64u)
                      if err then
                        vim.notify("Failed to create disk image: " .. err, vim.log.levels.ERROR)
                      else
                        vim.notify(string.format("Created %s disk image: %s", image_type:upper(), full_path), vim.log.levels.INFO)
                      end
                    end
                    show_browser(current_path)
                  end)
                  return
                end

                local _, err = exec_c64u(cmd_args, c64_config.c64u)
                if err then
                  vim.notify("Failed to create disk image: " .. err, vim.log.levels.ERROR)
                else
                  vim.notify(string.format("Created %s disk image: %s", image_type:upper(), full_path), vim.log.levels.INFO)
                end
                show_browser(current_path)
              end)
            end)
          end)
        end)

        -- Create directory (Ctrl-d)
        map("i", "<C-d>", function()
          vim.ui.input({
            prompt = "Directory name: ",
            default = "NEWDIR"
          }, function(dirname)
            if not dirname or dirname == "" then
              return
            end

            -- Create directory via FTP
            local script_file = vim.fn.tempname()
            local ftp_commands = string.format([[
open %s %s
user anonymous anonymous@
cd %s
mkdir %s
bye
]], host, ftp_port, current_path, dirname)

            vim.fn.writefile(vim.split(ftp_commands, "\n"), script_file)
            local cmd = string.format("ftp -n < %s 2>&1", vim.fn.shellescape(script_file))
            local output = vim.fn.system(cmd)
            vim.fn.delete(script_file)

            if vim.v.shell_error == 0 then
              vim.notify(string.format("Created directory: %s/%s", current_path, dirname), vim.log.levels.INFO)
              -- Refresh browser
              actions.close(prompt_bufnr)
              show_browser(current_path)
            else
              vim.notify("Failed to create directory: " .. output, vim.log.levels.ERROR)
            end
          end)
        end)

        -- Mount disk image (Ctrl-y)
        map("i", "<C-y>", function()
          local selection = action_state.get_selected_entry()
          if not selection then
            return
          end

          local entry = selection.value

          -- Check if it's a disk image file
          if entry.is_dir or not entry.name:match("%.d%d%d$") then
            vim.notify("Please select a disk image file (.d64, .d71, .d81)", vim.log.levels.WARN)
            return
          end

          -- Let user select drive name (a or b)
          select_drive_name(function(drive_name)
            vim.ui.select({ "readonly", "readwrite", "unlinked" }, {
              prompt = "Mount mode:",
            }, function(mode)
              if not mode then
                show_browser(current_path)
                return
              end

              local _, err = exec_c64u({
                "drives", "mount", drive_name, entry.path, "--mode", mode
              }, c64_config.c64u)

              if err then
                vim.notify("Failed to mount disk: " .. err, vim.log.levels.ERROR)
              else
                vim.notify(string.format("Mounted %s to drive %s", entry.name, drive_name), vim.log.levels.INFO)
              end

              -- Reopen browser
              show_browser(current_path)
            end)
          end)
        end)

        -- Unmount disk image (Ctrl-u)
        map("i", "<C-u>", function()
          -- Let user select drive name (a or b)
          select_drive_name(function(drive_name)
            local _, err = exec_c64u({ "drives", "unmount", drive_name }, c64_config.c64u)

            if err then
              vim.notify("Failed to unmount disk: " .. err, vim.log.levels.ERROR)
            else
              vim.notify("Disk unmounted from drive " .. drive_name, vim.log.levels.INFO)
            end

            -- Reopen browser
            show_browser(current_path)
          end)
        end)

        -- Note: User can close picker with Esc or Ctrl-c in normal mode

        return true
      end,
    }):find()
  end

  -- Start browser at root
  show_browser("/")
end

-- PRG files picker (for upload)
M.upload_prg = function(opts)
  opts = opts or {}

  -- Get config from c64 module
  local ok, c64_module = pcall(require, "c64")
  if not ok or not c64_module.config or not c64_module.config.c64u then
    vim.notify("c64.nvim not properly configured. Please ensure c64u section is set up.", vim.log.levels.ERROR)
    return
  end

  local config = c64_module.config

  require("telescope.builtin").find_files({
    prompt_title = "Select PRG to Upload",
    cwd = vim.fn.getcwd(),
    find_command = { "fd", "--type", "f", "--extension", "prg" },
    attach_mappings = function(prompt_bufnr, _map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if selection then
          local prg_file = selection.path or selection.value

          vim.ui.select({ "Upload and run", "Upload only" }, {
            prompt = "Action:",
          }, function(choice)
            if choice then
              local cmd = choice == "Upload and run"
                and { "runners", "run-prg-upload", prg_file }
                or { "runners", "load-prg-upload", prg_file }

              local _, upload_err = exec_c64u(cmd, config.c64u)

              if upload_err then
                vim.notify("Failed to upload PRG: " .. upload_err, vim.log.levels.ERROR)
              else
                vim.notify(string.format("PRG uploaded: %s", vim.fn.fnamemodify(prg_file, ":t")), vim.log.levels.INFO)
              end
            end
          end)
        end
      end)

      return true
    end,
  })
end

-- Assemble and upload current file
M.assemble_and_upload = function(opts)
  opts = opts or {}

  -- Get config from c64 module
  local ok, c64_module = pcall(require, "c64")
  if not ok or not c64_module.config or not c64_module.config.c64u then
    vim.notify("c64.nvim not properly configured. Please ensure c64u section is set up.", vim.log.levels.ERROR)
    return
  end

  local config = c64_module.config

  -- First assemble
  vim.notify("Assembling...", vim.log.levels.INFO)
  require("c64.assembler").assemble(config)

  -- Wait for assembly to complete
  vim.defer_fn(function()
    local prg_file = vim.fn.expand("%:p:r") .. ".prg"

    if vim.fn.filereadable(prg_file) ~= 1 then
      vim.notify("Assembly failed - no PRG file created", vim.log.levels.ERROR)
      return
    end

    -- Upload and run
    local _, upload_err = exec_c64u({
      "runners", "run-prg-upload", prg_file
    }, config.c64u)

    if upload_err then
      vim.notify("Failed to upload PRG: " .. upload_err, vim.log.levels.ERROR)
    else
      vim.notify("Program running on C64 Ultimate!", vim.log.levels.INFO)
    end
  end, 1000)
end

-- Machine control picker
M.machine = function(opts)
  opts = opts or {}

  -- Get config from c64 module
  local ok, c64_module = pcall(require, "c64")
  if not ok or not c64_module.config or not c64_module.config.c64u then
    vim.notify("c64.nvim not properly configured. Please ensure c64u section is set up.", vim.log.levels.ERROR)
    return
  end

  local config = c64_module.config

  local machine_commands = {
    { name = "Reset", command = "reset", description = "Reset the machine" },
    { name = "Reboot", command = "reboot", description = "Reboot with cartridge reinit" },
    { name = "Pause", command = "pause", description = "Pause via DMA" },
    { name = "Resume", command = "resume", description = "Resume from pause" },
    { name = "Power Off", command = "poweroff", description = "Power off (U64 only)" },
  }

  pickers.new(opts, {
    prompt_title = "C64 Ultimate Machine Control",
    finder = finders.new_table({
      results = machine_commands,
      entry_maker = function(entry)
        return {
          value = entry,
          display = string.format("%-12s %s", entry.name, entry.description),
          ordinal = entry.name .. " " .. entry.description,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    layout_strategy = "center",
    layout_config = {
      width = 0.5,
      height = 0.4,
    },
    attach_mappings = function(prompt_bufnr, map)
      -- Override default selection to NOT close the picker
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end

        local cmd = selection.value

        -- Execute the command
        local _, err = exec_c64u({ "machine", cmd.command }, config.c64u)

        if err then
          vim.notify("Error: " .. err, vim.log.levels.ERROR)
        else
          vim.notify(cmd.name .. " executed successfully", vim.log.levels.INFO)
        end

        -- DO NOT close the picker - refresh it instead
        -- Just stay in the picker so user can execute more commands
      end)

      -- Prevent command-line window (q:) from being triggered
      -- Map : in insert mode to close the picker instead
      map("i", ":", function()
        actions.close(prompt_bufnr)
      end)

      -- Also map : in normal mode to close the picker
      map("n", ":", function()
        actions.close(prompt_bufnr)
      end)

      return true
    end,
  }):find()
end

return telescope.register_extension({
  exports = {
    drives = M.drives,
    upload_prg = M.upload_prg,
    assemble_and_upload = M.assemble_and_upload,
    machine = M.machine,
  },
})
