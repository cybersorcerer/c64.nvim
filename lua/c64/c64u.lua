-- C64 Ultimate integration module
-- Provides functions to interact with C64 Ultimate hardware via c64u CLI

local M = {}

-- Check if c64u CLI is available
local function is_c64u_available()
	return vim.fn.executable("c64u") == 1
end

-- Execute c64u command and return output
local function exec_c64u(args, opts)
	opts = opts or {}

	if not is_c64u_available() then
		vim.notify("c64u CLI not found in PATH. Please install it first.", vim.log.levels.ERROR)
		return nil
	end

	-- Build command
	local cmd = { "c64u" }

	-- Add host/port if configured
	if opts.host then
		table.insert(cmd, "--host")
		table.insert(cmd, opts.host)
	end

	if opts.port then
		table.insert(cmd, "--port")
		table.insert(cmd, tostring(opts.port))
	end

	-- Add JSON flag for machine-readable output
	if opts.json then
		table.insert(cmd, "--json")
	end

	-- Add the actual command arguments
	for _, arg in ipairs(args) do
		table.insert(cmd, arg)
	end

	-- Execute command
	local output = vim.fn.system(cmd)
	local exit_code = vim.v.shell_error

	if exit_code ~= 0 then
		vim.notify("c64u command failed: " .. output, vim.log.levels.ERROR)
		return nil
	end

	return output
end

-- Upload and run PRG file on C64 Ultimate
function M.upload_and_run(config, prg_file)
	if not prg_file or prg_file == "" then
		vim.notify("No PRG file specified", vim.log.levels.ERROR)
		return
	end

	-- Check if file exists
	if vim.fn.filereadable(prg_file) ~= 1 then
		vim.notify(string.format("PRG file not found: %s", prg_file), vim.log.levels.ERROR)
		return
	end

	vim.notify(string.format("Uploading and running: %s", vim.fn.fnamemodify(prg_file, ":t")), vim.log.levels.INFO)

	local output = exec_c64u({ "runners", "run-prg-upload", prg_file }, config.c64u)

	if output then
		vim.notify("Program uploaded and running on C64 Ultimate!", vim.log.levels.INFO)
	end
end

-- Upload PRG file without running
function M.upload_only(config, prg_file)
	if not prg_file or prg_file == "" then
		vim.notify("No PRG file specified", vim.log.levels.ERROR)
		return
	end

	-- Check if file exists
	if vim.fn.filereadable(prg_file) ~= 1 then
		vim.notify(string.format("PRG file not found: %s", prg_file), vim.log.levels.ERROR)
		return
	end

	vim.notify(string.format("Uploading: %s", vim.fn.fnamemodify(prg_file, ":t")), vim.log.levels.INFO)

	local output = exec_c64u({ "runners", "load-prg-upload", prg_file }, config.c64u)

	if output then
		vim.notify("Program uploaded to C64 Ultimate!", vim.log.levels.INFO)
	end
end

-- Reset C64 Ultimate
function M.reset(config)
	vim.notify("Resetting C64 Ultimate...", vim.log.levels.INFO)

	local output = exec_c64u({ "machine", "reset" }, config.c64u)

	if output then
		vim.notify("C64 Ultimate reset complete", vim.log.levels.INFO)
	end
end

-- Assemble current file and upload to C64 Ultimate
function M.assemble_and_run(config)
	local current_file = vim.fn.expand("%:p")
	local prg_file = vim.fn.expand("%:p:r") .. ".prg"

	-- First, assemble the file
	vim.notify("Assembling: " .. vim.fn.fnamemodify(current_file, ":t"), vim.log.levels.INFO)

	local assembler = require("c64.assembler")
	assembler.assemble(config)

	-- Wait a bit for assembly to complete
	vim.defer_fn(function()
		-- Check if PRG was created
		if vim.fn.filereadable(prg_file) == 1 then
			M.upload_and_run(config, prg_file)
		else
			vim.notify("Assembly failed - no PRG file created", vim.log.levels.ERROR)
		end
	end, 500)
end

-- Mount disk image
function M.mount_disk(config, drive, image_file, mode)
	drive = drive or "8"
	mode = mode or "readonly"

	if not image_file or image_file == "" then
		vim.notify("No disk image specified", vim.log.levels.ERROR)
		return
	end

	-- Check if file exists
	if vim.fn.filereadable(image_file) ~= 1 then
		vim.notify(string.format("Disk image not found: %s", image_file), vim.log.levels.ERROR)
		return
	end

	vim.notify(string.format("Mounting %s to drive %s...", vim.fn.fnamemodify(image_file, ":t"), drive), vim.log.levels.INFO)

	local output = exec_c64u({ "drives", "mount-upload", drive, image_file, "--mode", mode }, config.c64u)

	if output then
		vim.notify(string.format("Disk mounted to drive %s", drive), vim.log.levels.INFO)
	end
end

-- Unmount disk
function M.unmount_disk(config, drive)
	drive = drive or "8"

	vim.notify(string.format("Unmounting drive %s...", drive), vim.log.levels.INFO)

	local output = exec_c64u({ "drives", "unmount", drive }, config.c64u)

	if output then
		vim.notify(string.format("Drive %s unmounted", drive), vim.log.levels.INFO)
	end
end

-- Get C64 Ultimate API version
function M.get_version(config)
	local output = exec_c64u({ "about", "--json" }, vim.tbl_extend("force", config.c64u or {}, { json = true }))

	if output then
		local ok, data = pcall(vim.json.decode, output)
		if ok and data.version then
			vim.notify(string.format("C64 Ultimate API version: %s", data.version), vim.log.levels.INFO)
		else
			vim.notify(output, vim.log.levels.INFO)
		end
	end
end

-- List drives
function M.list_drives(config)
	local output = exec_c64u({ "drives", "list" }, config.c64u)

	if output then
		-- Open output in a floating window or buffer
		local buf = vim.api.nvim_create_buf(false, true)
		local lines = vim.split(output, "\n")
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

		-- Get editor dimensions
		local width = math.floor(vim.o.columns * 0.8)
		local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.6))

		-- Calculate position
		local row = math.floor((vim.o.lines - height) / 2)
		local col = math.floor((vim.o.columns - width) / 2)

		-- Create floating window
		local opts = {
			relative = "editor",
			width = width,
			height = height,
			row = row,
			col = col,
			style = "minimal",
			border = "rounded",
			title = " C64 Ultimate Drives ",
			title_pos = "center",
		}

		local win = vim.api.nvim_open_win(buf, true, opts)

		-- Set buffer options
		vim.bo[buf].buftype = "nofile"
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].filetype = "text"

		-- Close on q
		vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, nowait = true })
	end
end

return M
