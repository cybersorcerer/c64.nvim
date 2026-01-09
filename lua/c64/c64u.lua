-- C64 Ultimate integration module
-- Provides basic functions to interact with C64 Ultimate hardware via c64u CLI
-- For advanced features (drives, PRG upload), use the Telescope extension

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

-- Get C64 Ultimate API version
function M.get_version(config)
	local output = exec_c64u({ "about" }, vim.tbl_extend("force", config.c64u or {}, { json = true }))

	if output then
		local ok, data = pcall(vim.json.decode, output)
		if ok and data.version then
			vim.notify(string.format("C64 Ultimate API version: %s", data.version), vim.log.levels.INFO)
		else
			vim.notify(output, vim.log.levels.INFO)
		end
	end
end

-- Create directory on C64U partition
function M.create_partition_directory(config)
	-- Get drives list to show available partitions
	local output = exec_c64u({ "drives", "list" }, vim.tbl_extend("force", config.c64u or {}, { json = true }))

	if not output then
		return
	end

	local ok, data = pcall(vim.json.decode, output)
	if not ok or not data or not data.drives then
		vim.notify("Failed to get drives list", vim.log.levels.ERROR)
		return
	end

	-- Extract partitions from drives
	local partitions = {}
	for _, drive_data in ipairs(data.drives) do
		local drive_name, drive_info = next(drive_data)
		if drive_info and drive_info.partitions then
			for _, partition in ipairs(drive_info.partitions) do
				if partition.path then
					table.insert(partitions, {
						path = partition.path,
						id = partition.id,
						drive = drive_name,
					})
				end
			end
		end
	end

	if #partitions == 0 then
		vim.notify("No partitions found. Enable IEC Drive first.", vim.log.levels.WARN)
		return
	end

	-- Select partition
	local partition_labels = {}
	for _, p in ipairs(partitions) do
		table.insert(partition_labels, string.format("%s (Drive: %s)", p.path, p.drive))
	end

	vim.ui.select(partition_labels, {
		prompt = "Select partition:",
	}, function(choice, idx)
		if not choice then
			return
		end

		local selected_partition = partitions[idx]

		-- Prompt for directory name
		vim.ui.input({
			prompt = "Directory name: ",
			default = "NEWDIR"
		}, function(dirname)
			if not dirname or dirname == "" then
				return
			end

			-- Create directory path
			local dir_path = selected_partition.path .. dirname

			-- Use Lua's filesystem to create directory
			local success, err = pcall(vim.fn.mkdir, dir_path, "p")

			if success then
				vim.notify(string.format("Created directory: %s", dir_path), vim.log.levels.INFO)
			else
				vim.notify(string.format("Failed to create directory: %s", err or "unknown error"), vim.log.levels.ERROR)
			end
		end)
	end)
end

-- Create a new disk image
function M.create_disk_image(config)
	-- Select disk image type
	vim.ui.select({ "d64 (35 tracks)", "d64 (40 tracks)", "d71 (70 tracks)", "d81 (160 tracks)", "g64 (raw GCR)", "dnp (custom tracks)" }, {
		prompt = "Select disk image type:",
	}, function(choice)
		if not choice then
			return
		end

		-- Extract type
		local image_type = choice:match("^(%w+)")

		-- Prompt for filename
		vim.ui.input({
			prompt = "Disk image filename (without extension): ",
			default = "disk"
		}, function(filename)
			if not filename or filename == "" then
				return
			end

			-- Add extension
			local full_path = filename .. "." .. image_type

			-- Prompt for disk name (label)
			vim.ui.input({
				prompt = "Disk name/label (max 16 chars): ",
				default = string.upper(filename:sub(1, 16))
			}, function(disk_name)
				if not disk_name or disk_name == "" then
					disk_name = string.upper(filename:sub(1, 16))
				end

				local cmd_args = { "files", "create-" .. image_type, full_path, "--name", disk_name }

				-- Special handling for d64 40-track and dnp
				if choice:match("40 tracks") then
					table.insert(cmd_args, "--tracks")
					table.insert(cmd_args, "40")
				elseif image_type == "dnp" then
					vim.ui.input({
						prompt = "Number of tracks (1-255): ",
						default = "35"
					}, function(tracks)
						if not tracks or tracks == "" then
							return
						end
						table.insert(cmd_args, "--tracks")
						table.insert(cmd_args, tracks)

						local output = exec_c64u(cmd_args, config.c64u)
						if output then
							vim.notify(string.format("Created %s disk image: %s", image_type:upper(), full_path), vim.log.levels.INFO)
						end
					end)
					return
				end

				local output = exec_c64u(cmd_args, config.c64u)
				if output then
					vim.notify(string.format("Created %s disk image: %s", image_type:upper(), full_path), vim.log.levels.INFO)
				end
			end)
		end)
	end)
end

-- Filesystem operations using c64u fs commands

-- List directory contents
function M.fs_list(path, config)
	path = path or "/"
	local output = exec_c64u({ "fs", "ls", path }, config.c64u or {})

	if output then
		vim.notify(output, vim.log.levels.INFO)
	end
end

-- Upload file to C64 Ultimate
function M.fs_upload(local_file, remote_path, config)
	if not local_file or local_file == "" then
		vim.notify("No local file specified", vim.log.levels.ERROR)
		return
	end

	-- Expand file path
	local_file = vim.fn.expand(local_file)

	if vim.fn.filereadable(local_file) ~= 1 then
		vim.notify(string.format("File not found: %s", local_file), vim.log.levels.ERROR)
		return
	end

	-- If no remote path specified, upload to /Temp with same filename
	if not remote_path or remote_path == "" then
		local filename = vim.fn.fnamemodify(local_file, ":t")
		remote_path = "/Temp/" .. filename
	end

	vim.notify(string.format("Uploading %s to %s...", vim.fn.fnamemodify(local_file, ":t"), remote_path), vim.log.levels.INFO)

	local output = exec_c64u({ "fs", "upload", local_file, remote_path }, config.c64u or {})

	if output then
		vim.notify(string.format("Uploaded: %s", remote_path), vim.log.levels.INFO)
	end
end

-- Download file from C64 Ultimate
function M.fs_download(remote_path, local_file, config)
	if not remote_path or remote_path == "" then
		vim.notify("No remote path specified", vim.log.levels.ERROR)
		return
	end

	-- If no local file specified, download to current directory
	if not local_file or local_file == "" then
		local filename = vim.fn.fnamemodify(remote_path, ":t")
		local_file = "./" .. filename
	end

	-- Expand path
	local_file = vim.fn.expand(local_file)

	vim.notify(string.format("Downloading %s to %s...", remote_path, local_file), vim.log.levels.INFO)

	local output = exec_c64u({ "fs", "download", remote_path, local_file }, config.c64u or {})

	if output then
		vim.notify(string.format("Downloaded: %s", local_file), vim.log.levels.INFO)
	end
end

-- Create directory on C64 Ultimate
function M.fs_mkdir(path, config)
	if not path or path == "" then
		vim.notify("No directory path specified", vim.log.levels.ERROR)
		return
	end

	local output = exec_c64u({ "fs", "mkdir", path }, config.c64u or {})

	if output then
		vim.notify(string.format("Created directory: %s", path), vim.log.levels.INFO)
	end
end

-- Remove file or directory on C64 Ultimate
function M.fs_remove(path, config)
	if not path or path == "" then
		vim.notify("No path specified", vim.log.levels.ERROR)
		return
	end

	-- Confirm deletion
	vim.ui.input({
		prompt = string.format("Delete '%s'? (yes/no): ", path),
	}, function(input)
		if input and input:lower() == "yes" then
			local output = exec_c64u({ "fs", "rm", path }, config.c64u or {})

			if output then
				vim.notify(string.format("Removed: %s", path), vim.log.levels.INFO)
			end
		else
			vim.notify("Deletion cancelled", vim.log.levels.INFO)
		end
	end)
end

-- Move/rename file on C64 Ultimate
function M.fs_move(source, dest, config)
	if not source or source == "" then
		vim.notify("No source path specified", vim.log.levels.ERROR)
		return
	end

	if not dest or dest == "" then
		vim.notify("No destination path specified", vim.log.levels.ERROR)
		return
	end

	local output = exec_c64u({ "fs", "mv", source, dest }, config.c64u or {})

	if output then
		vim.notify(string.format("Moved: %s -> %s", source, dest), vim.log.levels.INFO)
	end
end

-- Copy file on C64 Ultimate
function M.fs_copy(source, dest, config)
	if not source or source == "" then
		vim.notify("No source path specified", vim.log.levels.ERROR)
		return
	end

	if not dest or dest == "" then
		vim.notify("No destination path specified", vim.log.levels.ERROR)
		return
	end

	vim.notify(string.format("Copying %s to %s...", source, dest), vim.log.levels.INFO)

	local output = exec_c64u({ "fs", "cp", source, dest }, config.c64u or {})

	if output then
		vim.notify(string.format("Copied: %s -> %s", source, dest), vim.log.levels.INFO)
	end
end

-- Show file information
function M.fs_cat(path, config)
	if not path or path == "" then
		vim.notify("No path specified", vim.log.levels.ERROR)
		return
	end

	local output = exec_c64u({ "fs", "cat", path }, config.c64u or {})

	if output then
		vim.notify(output, vim.log.levels.INFO)
	end
end

return M
