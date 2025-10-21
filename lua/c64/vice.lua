-- VICE Emulator integration

local M = {}

-- State tracking for monitor session
local monitor_state = {
	active = false,        -- Is VICE running?
	terminal_buf = nil,    -- Terminal buffer ID
	terminal_win = nil,    -- Floating window ID
	terminal_chan = nil,   -- Terminal channel ID
	vice_job_id = nil,     -- VICE job ID
}

-- Helper function to find PRG and SYM files
local function find_program_files()
	local prg_file = vim.fn.expand("%:p:r") .. ".prg"
	local sym_file = vim.fn.expand("%:p:r") .. ".sym"

	return {
		prg = prg_file,
		sym = sym_file,
		prg_exists = vim.fn.filereadable(prg_file) == 1,
		sym_exists = vim.fn.filereadable(sym_file) == 1,
	}
end

-- Cleanup function for monitor session
local function cleanup_monitor_session()
	-- Prevent double cleanup
	if not monitor_state.active then
		return
	end

	-- Mark as inactive immediately to prevent re-entry
	monitor_state.active = false

	-- Kill the terminal job
	if monitor_state.terminal_chan then
		pcall(vim.fn.jobstop, monitor_state.terminal_chan)
	end

	-- Clean shutdown: kill x64/x64sc and netcat
	vim.fn.system("killall x64 x64sc 2>/dev/null")
	vim.fn.system("pkill -f 'nc localhost 6510' 2>/dev/null")

	-- Close floating window if it exists
	if monitor_state.terminal_win and vim.api.nvim_win_is_valid(monitor_state.terminal_win) then
		pcall(vim.api.nvim_win_close, monitor_state.terminal_win, true)
	end

	-- Delete terminal buffer if it exists
	if monitor_state.terminal_buf and vim.api.nvim_buf_is_valid(monitor_state.terminal_buf) then
		pcall(vim.api.nvim_buf_delete, monitor_state.terminal_buf, { force = true })
	end

	-- Kill VICE job if we started it
	if monitor_state.vice_job_id then
		pcall(vim.fn.jobstop, monitor_state.vice_job_id)
	end

	-- Reset state
	monitor_state.terminal_buf = nil
	monitor_state.terminal_win = nil
	monitor_state.terminal_chan = nil
	monitor_state.vice_job_id = nil

	vim.notify("VICE monitor session closed. Press <leader>km to start fresh.", vim.log.levels.INFO)
end

-- Create floating window for monitor terminal
local function create_floating_window(buf, enter, title)
	-- Set up custom highlight for VICE monitor title (bold)
	vim.api.nvim_set_hl(0, "ViceMonitorTitle", { bold = true, fg = "#89b4fa" })

	-- Get editor dimensions
	local width = vim.o.columns
	local height = vim.o.lines

	-- Calculate floating window size (80% width, 60% height)
	local win_width = math.floor(width * 0.8)
	local win_height = math.floor(height * 0.6)

	-- Calculate position to center the window
	local row = math.floor((height - win_height) / 2)
	local col = math.floor((width - win_width) / 2)

	-- Create the floating window
	-- enter parameter controls whether to focus immediately
	if enter == nil then
		enter = true
	end

	-- Prepare title if provided
	local win_opts = {
		relative = "editor",
		width = win_width,
		height = win_height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	}

	-- Add title if provided with custom highlight
	if title then
		win_opts.title = { { title, "ViceMonitorTitle" } }
		win_opts.title_pos = "center"
	end

	local win = vim.api.nvim_open_win(buf, enter, win_opts)

	return win
end

-- Run the current program in VICE
function M.run(config)
	-- Check if VICE is available
	if vim.fn.executable(config.vice_binary) ~= 1 then
		vim.notify(string.format("VICE emulator '%s' not found in PATH", config.vice_binary), vim.log.levels.ERROR)
		return
	end

	local files = find_program_files()

	-- Check if PRG file exists
	if not files.prg_exists then
		vim.notify(
			string.format(
				"PRG file not found: %s\nPlease assemble the program first using <leader>ka",
				vim.fn.fnamemodify(files.prg, ":t")
			),
			vim.log.levels.WARN
		)
		return
	end

	-- Build VICE command
	local cmd = string.format("%s %s &", config.vice_binary, vim.fn.shellescape(files.prg))

	vim.notify("Starting VICE with: " .. vim.fn.fnamemodify(files.prg, ":t"), vim.log.levels.INFO)

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

-- Toggle VICE monitor (floating terminal)
function M.toggle_monitor(config)
	-- If monitor window is visible, hide it
	if monitor_state.terminal_win and vim.api.nvim_win_is_valid(monitor_state.terminal_win) then
		vim.api.nvim_win_close(monitor_state.terminal_win, true)
		monitor_state.terminal_win = nil
		return
	end

	-- If session is active but window is hidden, show it again
	if monitor_state.active and monitor_state.terminal_buf and vim.api.nvim_buf_is_valid(monitor_state.terminal_buf) then
		monitor_state.terminal_win = create_floating_window(monitor_state.terminal_buf)
		vim.cmd("startinsert")
		return
	end

	-- Start new monitor session
	local files = find_program_files()

	-- Check if PRG file exists
	if not files.prg_exists then
		vim.notify(
			string.format(
				"PRG file not found: %s\nPlease assemble the program first using <leader>ka",
				vim.fn.fnamemodify(files.prg, ":t")
			),
			vim.log.levels.WARN
		)
		return
	end

	-- Check if x64 is already running with remotemonitor
	local x64_running = vim.fn.system("pgrep -f 'x64.*-remotemonitor'"):match("%d+")

	if not x64_running then
		-- Check if VICE is available
		if vim.fn.executable(config.vice_binary) ~= 1 then
			vim.notify(string.format("VICE emulator '%s' not found in PATH", config.vice_binary), vim.log.levels.ERROR)
			return
		end

		-- Build VICE command with -remotemonitor and minimized
		local cmd_parts = {
			config.vice_binary,
			"-remotemonitor",
			"-minimized", -- Start minimized (if supported)
		}

		-- Execute in background with command as table
		monitor_state.vice_job_id = vim.fn.jobstart(cmd_parts, {
			detach = true,
			on_exit = function(_, exit_code, _)
				-- Exit code 143 = 128 + 15 (SIGTERM) is normal when we kill VICE
				-- Exit code 0 is also normal
				if exit_code ~= 0 and exit_code ~= 143 then
					vim.notify("VICE debugger exited with error code: " .. exit_code, vim.log.levels.WARN)
				end
				cleanup_monitor_session()
			end,
		})
	end

	monitor_state.active = true

	-- Open floating terminal with netcat connection to VICE monitor
	vim.defer_fn(function()
		-- Create a new buffer for the terminal
		local term_buf = vim.api.nvim_create_buf(false, true)
		monitor_state.terminal_buf = term_buf

		-- Create title with program name and Nerd Font icon
		local prg_name = vim.fn.fnamemodify(files.prg, ":t")
		-- Nerd Font icon: nf-md-desktop_classic
		-- Using direct hex code point
		local icon = "󰟀" -- U+F07C0 nf-md-desktop_classic
		local title = string.format("%s [ VICE Remote Monitor %s ]", icon, prg_name)

		-- Create floating window WITHOUT focusing it first (enter = false)
		monitor_state.terminal_win = create_floating_window(term_buf, false, title)

		-- Create a wrapper script that adds header and sets colors
		local wrapper_cmd = string.format([[
      printf '\033[1;94m╔══════════════════════════════════════════════════════════════════╗\033[0m\n'
      printf '\033[1;94m║  VICE Monitor - Hide: <Esc><leader>km  Close: <esc>:q            ║\033[0m\n'
      printf '\033[1;94m╚══════════════════════════════════════════════════════════════════╝\033[0m\n'
      printf '\n'
      # Set BOLD yellow (1;33m) as default foreground color, then REPLACE shell with netcat
      printf '\033[1;33m'
      printf 'Connecting to VICE monitor...\n'
      # Give VICE a moment to be ready
      sleep 2
      exec nc localhost 6510
    ]])

		-- We need to set the current window to the floating window before termopen
		-- Otherwise termopen will open in the wrong window
		vim.api.nvim_set_current_win(monitor_state.terminal_win)

		-- Start terminal with wrapper script
		monitor_state.terminal_chan = vim.fn.termopen({ "sh", "-c", wrapper_cmd })

		-- Note: Due to async terminal behavior, the user needs to click once
		-- or press 'i' to enter insert mode after the monitor connects

		-- Set buffer options to prevent LSP attachment
		-- Note: Don't set filetype to avoid potential input blocking issues
		-- vim.bo[term_buf].filetype = "vicemonitor"
		vim.bo[term_buf].buflisted = false

		-- Setup terminal buffer with quit handler (q in normal mode)
		vim.api.nvim_buf_set_keymap(term_buf, "n", "q", "", {
			noremap = true,
			silent = true,
			callback = function()
				cleanup_monitor_session()
			end,
		})

		-- Handle buffer deletion (via :q or :bdelete)
		vim.api.nvim_create_autocmd("BufDelete", {
			buffer = term_buf,
			once = true,
			callback = function()
				cleanup_monitor_session()
			end,
		})

		-- Detach any LSP clients from this buffer
		vim.defer_fn(function()
			local clients = vim.lsp.get_clients({ bufnr = term_buf })
			for _, client in ipairs(clients) do
				vim.lsp.buf_detach_client(term_buf, client.id)
			end
		end, 100)

		-- Load the PRG file via monitor (doesn't auto-run)
		vim.defer_fn(function()
			-- Check if terminal buffer is still valid and channel exists
			if monitor_state.terminal_buf
				and vim.api.nvim_buf_is_valid(monitor_state.terminal_buf)
				and monitor_state.terminal_chan
				and files.prg_exists then
				-- VICE monitor load command: load "filename" 0
				local ok = pcall(vim.fn.chansend, monitor_state.terminal_chan, string.format('load "%s" 0\n', files.prg))
				if not ok then
					-- Channel is closed or invalid, skip silently
					return
				end
			end
		end, 300)

		-- If we have symbols, send label commands after connection
		if files.sym_exists then
			vim.defer_fn(function()
				-- Check if terminal buffer is still valid and channel exists
				if not monitor_state.terminal_buf
					or not vim.api.nvim_buf_is_valid(monitor_state.terminal_buf)
					or not monitor_state.terminal_chan then
					return
				end

				local ok, sym_content = pcall(vim.fn.readfile, files.sym)
				if not ok then
					return
				end

				for _, line in ipairs(sym_content) do
					local label, addr = line:match("%.label%s+([^=]+)=%$(%x+)")
					if label and addr then
						-- Send VICE add label command: al C:addr .label
						pcall(vim.fn.chansend, monitor_state.terminal_chan, string.format("al C:%s .%s\n", addr, label))
					end
				end
			end, 500)
		end
	end, 2000)
end

-- Keep old debug function for backward compatibility, redirect to toggle_monitor
function M.debug(config)
	M.toggle_monitor(config)
end

-- Focus the monitor window and enter insert mode
function M.focus_monitor()
	if monitor_state.terminal_win and vim.api.nvim_win_is_valid(monitor_state.terminal_win) then
		vim.api.nvim_set_current_win(monitor_state.terminal_win)
		vim.cmd("startinsert")
	else
		vim.notify("VICE monitor window is not open. Press <leader>km to start.", vim.log.levels.WARN)
	end
end

return M
