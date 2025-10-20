-- VICE Emulator integration

local M = {}

-- Track if a debug session is already running
local debug_session_active = false
local monitor_terminal_buf = nil

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

-- Run the current program in VICE with debug mode (monitor enabled + symbol file)
function M.debug(config)
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

	if x64_running then
		-- x64 is already running, just connect to existing monitor
		vim.notify("VICE already running, connecting to existing monitor...", vim.log.levels.INFO)
	else
		-- Start new x64 instance
		if debug_session_active then
			vim.notify("VICE debug session already running. Close VICE first.", vim.log.levels.WARN)
			return
		end

		-- Check if VICE is available
		if vim.fn.executable(config.vice_binary) ~= 1 then
			vim.notify(string.format("VICE emulator '%s' not found in PATH", config.vice_binary), vim.log.levels.ERROR)
			return
		end

		debug_session_active = true

		-- Build VICE command with -remotemonitor and minimized
		-- Don't load the PRG automatically - we'll load it via monitor
		local cmd_parts = {
			config.vice_binary,
			"-remotemonitor",
			"-minimized", -- Start minimized (if supported)
			"&",
		}

		local cmd = table.concat(cmd_parts, " ")

		if files.sym_exists then
			vim.notify(
				string.format(
					"Starting VICE minimized with remote monitor and symbols: %s",
					vim.fn.fnamemodify(files.sym, ":t")
				),
				vim.log.levels.INFO
			)
		else
			vim.notify("Starting VICE minimized with remote monitor", vim.log.levels.INFO)
		end

		-- Execute in background
		vim.fn.jobstart(cmd, {
			detach = true,
			on_exit = function(_, exit_code, _)
				debug_session_active = false
				monitor_terminal_buf = nil
				if exit_code ~= 0 then
					vim.notify("VICE debugger exited with error code: " .. exit_code, vim.log.levels.WARN)
				end
			end,
		})
	end

	-- Open a terminal split with netcat connection to VICE monitor
	vim.defer_fn(function()
		-- Check if monitor terminal buffer still exists and is displayed in a window
		if monitor_terminal_buf and vim.api.nvim_buf_is_valid(monitor_terminal_buf) then
			-- Check if buffer is actually displayed in any window
			local buf_in_window = false
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_get_buf(win) == monitor_terminal_buf then
					buf_in_window = true
					break
				end
			end

			if buf_in_window then
				vim.notify("VICE Monitor terminal already opened", vim.log.levels.WARN)
				return
			else
				-- Buffer exists but not displayed, clean up
				monitor_terminal_buf = nil
			end
		end

		-- Create a new buffer for the terminal
		local term_buf = vim.api.nvim_create_buf(false, true)
		monitor_terminal_buf = term_buf

		-- Open it in a horizontal split
		vim.cmd("split")
		vim.api.nvim_win_set_buf(0, term_buf)

		-- Create a wrapper script that adds header (light yellow) and sets lightblue for monitor
		local wrapper_cmd = string.format([[
      printf '\033[1;94m╔══════════════════════════════════════════════════════════════════╗\033[0m\n'
      printf '\033[1;94m║  VICE Monitor - Close with: <Esc><Esc>q                          ║\033[0m\n'
      printf '\033[1;94m╚══════════════════════════════════════════════════════════════════╝\033[0m\n'
      printf '\n'
      # Set lightblue as default foreground color, then run netcat
      printf '\033[93m'
      nc localhost 6510
    ]])

		-- Start terminal with wrapper script
		local term_chan = vim.fn.termopen({ "sh", "-c", wrapper_cmd })

		-- Immediately enter insert mode (cursor should be in terminal window already)
		vim.cmd("startinsert")

		-- Set buffer options to prevent LSP attachment
		vim.bo[term_buf].filetype = "vicemonitor"
		vim.bo[term_buf].buflisted = false

		-- Cleanup function for when monitor is closed
		local cleanup_debug_session = function()
			-- Kill the terminal job
			if term_chan then
				pcall(vim.fn.jobstop, term_chan)
			end

			-- Clean shutdown: kill x64/x64sc and netcat
			vim.fn.system("killall x64 x64sc 2>/dev/null")
			vim.fn.system("pkill -f 'nc localhost 6510' 2>/dev/null")

			-- Reset state
			monitor_terminal_buf = nil
			debug_session_active = false

			vim.notify("VICE debug session closed. Press <leader>kd to start fresh.", vim.log.levels.INFO)
		end

		-- Setup terminal buffer with quit handler (q in normal mode)
		vim.api.nvim_buf_set_keymap(term_buf, "n", "q", "", {
			noremap = true,
			silent = true,
			callback = function()
				cleanup_debug_session()
				vim.cmd("bdelete!")
			end,
		})

		-- Use WinClosed autocmd to detect when the window is closed
		-- This is more reliable than BufUnload for terminal buffers
		vim.api.nvim_create_autocmd("WinClosed", {
			callback = function(args)
				-- Check if the closed window contained our terminal buffer
				local closed_win = tonumber(args.match)
				if closed_win then
					-- Check all remaining windows to see if our buffer is still visible
					local buf_still_visible = false
					for _, win in ipairs(vim.api.nvim_list_wins()) do
						if vim.api.nvim_win_is_valid(win) then
							local buf = vim.api.nvim_win_get_buf(win)
							if buf == term_buf then
								buf_still_visible = true
								break
							end
						end
					end

					-- If buffer is not visible anymore and it's still our active monitor
					if not buf_still_visible and monitor_terminal_buf == term_buf then
						cleanup_debug_session()
					end
				end
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
			if term_chan and files.prg_exists then
				-- VICE monitor load command: load "filename" 0
				vim.fn.chansend(term_chan, string.format('load "%s" 0\n', files.prg))
			end
		end, 300)

		-- If we have symbols, send label commands after connection
		if files.sym_exists then
			vim.defer_fn(function()
				local sym_content = vim.fn.readfile(files.sym)
				for _, line in ipairs(sym_content) do
					local label, addr = line:match("%.label%s+([^=]+)=%$(%x+)")
					if label and addr then
						-- Send VICE add label command: al C:addr .label
						vim.fn.chansend(term_chan, string.format("al C:%s .%s\n", addr, label))
					end
				end
				vim.notify(
					string.format(
						"Loaded %d symbols. Program loaded but not started. Use 'g 0801' to run.",
						#sym_content
					),
					vim.log.levels.INFO
				)
			end, 500)
		end

		vim.notify("VICE Monitor connected! Type 'r' for registers, 'z' to run.", vim.log.levels.INFO)
	end, 2000)
end

return M
