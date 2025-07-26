-- Essentially there need to be two autocmds:
-- + one for cursors (location)
-- + one for buffer updates

local Job = require("plenary.job")
local uv = vim.uv

local state = require("state")

local M = {}

M.group = vim.api.nvim_create_augroup("CO-OP", { clear = true })
M.ns_id = vim.api.nvim_create_namespace("MultiplayerCursor")
M.vns_id = vim.api.nvim_create_namespace("MultiplayerCursorVisual")

M.players = {}

M.active = false

function M.init()
	M.client_number = 1
	M.username = state.config.username
	M.last_edit = {
		content = nil,
		flc = nil,
		llc = nil,
		llu = nil,
		buf = nil,
		line_count = nil,
		client_number = nil,
	}
end

-- This will eventually replace plenary
function M.start_connection_process(port)
	local handle, pid = uv.spawn("dumbpipe", {
		args = { "listen-tcp", "--host", "0.0.0.0:" .. port },
	}, function(code, signal) -- on exit
		print("exit code", code)
		print("exit signal", signal)
	end)

	M.process_handle = handle
end

function M.end_connection_process()
	local result = uv.process_kill(M.process_handle, "sigterm")
end

function M.track_cursor()
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		desc = "Track Cursor Movement",
		pattern = "*", -- for now
		group = M.group,
		callback = function(ev)
			local ok, res = pcall(vim.api.nvim_buf_get_var, ev.buf, "sharing")
			if ok and res then
				-- if vim.api.nvim_buf_get_var(ev.buf, "sharing") then
				local ok, connected_bufnr = pcall(vim.api.nvim_buf_get_var, ev.buf, "multiplayer_bufnr")
				if ok then
					local curpos = vim.api.nvim_win_get_cursor(0)

					local mark_letter = string.sub(M.username, 1, 1):lower()

					local mode = vim.api.nvim_get_mode()

					local vmarks = vim.fn.getpos("v")

					vim.rpcnotify(
						M.channel,
						"nvim_buf_set_mark",
						connected_bufnr,
						mark_letter,
						curpos[1],
						curpos[2],
						{}
					)

					vim.rpcnotify(
						M.channel,
						"nvim_exec_lua",
						[[return Multiplayer.coop.render_cursor(...)]],
						{ connected_bufnr, mark_letter, mode.mode, vmarks }
					)
				end
			end
		end,
	})
end

function M.track_edits(bufnr)
	M.last_edit.client_number = M.client_number
	vim.api.nvim_buf_attach(bufnr, true, {

		on_lines = function(lines, buf, cgt, flc, llc, llu, bcp)
			if M.last_edit.client_number ~= M.client_number then
				M.last_edit.client_number = M.client_number
			else
				-- vim.print({ cgt, flc, llc, llu, bcp })
				local content = vim.api.nvim_buf_get_lines(buf, flc, llu, false)
				-- vim.rpcnotify(M.channel, "nvim_buf_set_lines", 0, flc, llc, false, content)
				-- local line_count = vim.api.nvim_buf_get
				local line_count = vim.api.nvim_buf_line_count(buf)

				-- M.last_edit = {
				-- 	buf = buf,
				-- 	flc = flc,
				-- 	llc = llc,
				-- 	llu = llu,
				-- 	client_number = M.client_number,
				-- 	content = content,
				-- 	line_count = line_count,
				-- }

				local remote_bufnr = vim.api.nvim_buf_get_var(buf, "multiplayer_bufnr")

				local clientnr = M.client_number

				vim.rpcnotify(
					M.channel,
					"nvim_exec_lua",
					[[return Multiplayer.coop.apply_edits(...)]],
					{ content, remote_bufnr, flc, llc, llu, clientnr }
				)
				-- M.last_edit.client_number
			end

			-- vim.rpcnotify(M.channel, "nvim_exec_lua", [[return Multiplayer.coop.track_edits(...)]], { connected_bufnr })
		end,

		on_changedtick = function(changed_tick, buf, cgt)
			local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			-- vim.rpcnotify(M.channel, "nvim_buf_set_lines", 0, 0, -1, false, content)
		end,

		-- on_bytes = function(bytes, buf, cgt, srow, scol, bofc, oerow, oecol, oeblc, nerow, necol, neblc)
		-- 	local content = vim.api.nvim_buf_get_text(buf, srow, scol, srow + nerow, scol + necol, {})
		-- 	-- NOTE: This is where changes are sent
		-- 	vim.rpcnotify(M.channel, "nvim_buf_set_text", 0, srow, scol, srow + oerow, scol + oecol, content)
		-- end,

		on_reload = function(reload, buf)
			local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			-- vim.rpcnotify(M.channel, "nvim_buf_set_lines", 0, 0, -1, false, content)
		end,
	})
end

function M.apply_edits(lines, buf, flc, llc, llu, clientnr)
	-- vim.api.nvim_buf_set_lines(buf, flc, llc, false, lines)
	local connected_bufnr = vim.api.nvim_buf_get_var(0, "multiplayer_bufnr")

	M.last_edit.client_number = clientnr

	vim.api.nvim_buf_set_lines(buf, flc, llc, false, lines)
end

function M.test_track_edits(bufnr)
	vim.api.nvim_buf_attach(bufnr, false, {
		-- I need to track users
		on_lines = function(lines, buf, changedtick, flc, llc, llu, bcp)
			vim.print({
				-- lines,
				-- buf,
				-- changedtick,
				flc,
				llc,
				llu,
				-- bcp
				vim.api.nvim_buf_get_lines(0, flc, llc, false),
				vim.api.nvim_buf_get_lines(0, flc, llu, false),
			})
		end,
	})
end
function M.cleanup()
	vim.api.nvim_create_autocmd("VimLeavePre", {
		desc = "Cleanup",
		pattern = "*",
		group = M.group,
		callback = function()
			M.dumbpipe:shutdown()
		end,
	})
end

-- function M.dp(mode, address, ticket)
-- 	local args = {}
-- 	if mode == "host" then
-- 		args = { "listen-tcp", "--host", address }
-- 	elseif mode == "join" then
-- 		args = { "connect-tcp", "--addr", address, ticket }
-- 	end
-- 	local handle, pid = uv.spawn("dumbpipe", { args = args }, function(code, signal)
-- 		vim.print(code)
-- 		vim.print(signal)
-- 	end)
--
-- 	vim.api.nvim_create_autocmd("VimLeavePre", {
-- 		desc = "Cleanup UV",
-- 		pattern = "*",
-- 		group = M.group,
-- 		callback = function()
-- 			-- M.dumbpipe:shutdown()
-- 			uv.process_kill(handle, "sigterm")
-- 		end,
-- 	})
-- end

function M.host(port)
	M.init()
	port = port or Multiplayer.rust.port()
	local dumbpipe = Job:new({
		command = "dumbpipe",
		args = {
			"listen-tcp",
			"--host",
			"0.0.0.0:" .. port,
		},
		interactive = false,
		on_start = function()
			vim.print("started")
		end,
		on_stdout = function(error, data)
			vim.print(error)
			vim.print(data)
		end,
		on_stderr = function(error, data)
			vim.print(error)
			vim.print(data)
		end,
	})

	local address = vim.fn.serverstart("0.0.0.0:" .. port)

	dumbpipe:start()

	vim.api.nvim_create_autocmd("ChanInfo", {
		desc = "Detect New Client",
		pattern = "*", -- for now
		group = M.group,
		callback = function(ev)
			local all_clients = vim.api.nvim_list_chans()
			for _, client in ipairs(all_clients) do
				if client.client and client.client.name then
					if client.client.name == "Multiplayer" then
						vim.print("Connected")
						M.channel = client.id
						-- M.active = true
						M.on_connect("host")
					end
				end
			end
		end,
	})

	M.dumbpipe = dumbpipe

	M.cleanup()
	M.track_cursor()

	vim.print(address)
	return address
end

function M.join(ticket, port)
	M.init()
	M.client_number = 2 -- HACK:
	port = port or Multiplayer.rust.port()
	-- port = port or 6969
	local address = "0.0.0.0:" .. port
	vim.print(address)
	local dumbpipe = Job:new({
		command = "dumbpipe",
		args = {
			"connect-tcp",
			"--addr",
			address,
			ticket,
		},
		on_stdout = function(error, data)
			-- vim.print(error)
			vim.print(data)
		end,
		on_stderr = function(error, data)
			vim.print(error)
			vim.print(data)
		end,
	})

	dumbpipe:start()

	-- we have to wait just a bit for the socket to connect
	vim.defer_fn(function()
		local chan = vim.fn.sockconnect("tcp", address, { rpc = true })
		vim.print(chan)
		M.channel = chan

		M.on_connect("join")

		M.dumbpipe = dumbpipe

		M.cleanup()
		M.track_cursor()
	end, 1000)

	-- local chan = vim.fn.sockconnect("tcp", address, { rpc = true })
	--
	-- M.channel = chan
	--
	-- M.on_connect("join")
	--
	-- M.dumbpipe = dumbpipe
	--
	-- M.cleanup()
	-- M.track_cursor()
	--
	-- return chan
end

function M.on_connect(role)
	-- M.username = vim.system({ "git", "config", "user.name" }, { text = true }):wait().stdout
	-- M.username = vim.trim(M.username)

	vim.rpcrequest(
		M.channel,
		"nvim_set_client_info",
		"Multiplayer",
		{},
		"host",
		{},
		{ git_username = M.username, role = role }
	)

	M.active = true
end

function M.render_cursor(bufnr, letter, mode, vmarks)
	-- this function assumes that the mark is set for other players cursor position
	bufnr = bufnr or 0
	if vim.api.nvim_buf_get_var(bufnr, "sharing") then
		letter = letter or "p"

		local markpos = vim.api.nvim_buf_get_mark(bufnr, letter)

		-- local markpos = curpos
		-- local mark_set = vim.api.nvim_buf_set_mark(bufnr, letter, curpos[1], curpos[2], {})
		-- if not mark_set then
		-- 	markpos = vim.api.nvim_buf_get_mark(bufnr, letter)
		-- end

		-- vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, 0, -1)
		vim.api.nvim_buf_clear_namespace(bufnr, M.vns_id, 0, -1)
		if mode == "n" then
			vim.api.nvim_buf_del_extmark(bufnr, M.ns_id, M.channel + 1)
		end
		vim.api.nvim_buf_set_extmark(bufnr, M.ns_id, markpos[1] - 1, markpos[2], {
			hl_group = "Cursor",
			end_col = markpos[2] + 1,
			id = M.channel,
			strict = false,
		})

		local visual_modes = string.sub(mode, 1, 1):lower()

		if visual_modes == "v" then
			local vstart = markpos
			local vend = { vmarks[2], vmarks[3] }

			if markpos[1] > vmarks[2] then
				vstart = { vmarks[2], vmarks[3] }
				vend = markpos
			end

			if markpos[1] == vmarks[2] and markpos[2] > vmarks[3] then
				vstart = { markpos[1], vmarks[3] }
				vend = { vmarks[2], markpos[2] }
			end

			if markpos[1] == vmarks[2] and markpos[2] < vmarks[3] then
				vstart = { vmarks[2], markpos[2] }
				vend = { markpos[1], vmarks[3] }
			end

			vim.api.nvim_buf_set_extmark(bufnr, M.vns_id, vstart[1] - 1, vstart[2], {
				hl_group = "Visual",
				-- end_row = vmarks[2][1] - 1,
				-- end_col = vmarks[2][2],
				end_row = vend[1] - 1,
				end_col = vend[2],
				id = M.channel + 1,
				strict = false,
			})
		end

		-- if mode ~= "v" then
		-- 	vim.api.nvim_buf_del_extmark(bufnr, M.ns_id, M.channel + 1)
		-- end
	end
end

function M.share_buf(bufnr)
	bufnr = bufnr or 0

	local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
	local full_filename = vim.api.nvim_buf_get_name(bufnr)
	local base_filename = vim.fs.basename(full_filename)

	-- send buffer
	local connected_bufnr = vim.rpcrequest(M.channel, "nvim_create_buf", true, false)

	vim.rpcrequest(M.channel, "nvim_set_option_value", "buftype", "acwrite", { buf = connected_bufnr })
	vim.rpcrequest(M.channel, "nvim_set_option_value", "filetype", filetype, { buf = connected_bufnr })
	vim.rpcrequest(M.channel, "nvim_buf_set_name", connected_bufnr, base_filename)

	vim.rpcrequest(M.channel, "nvim_create_autocmd", "BufWriteCmd", {
		desc = "Sharing " .. base_filename,
		-- group = M.group, -- invalid group
		buffer = connected_bufnr,
		-- command = "set nomodified",
		command = "lua Multiplayer.coop.join_sync_buf(" .. connected_bufnr .. ") | set nomodified",
	})

	vim.api.nvim_create_autocmd("BufWritePost", {
		desc = "Sync Buffer on Write",
		buffer = bufnr,
		group = M.group,
		callback = function()
			M.host_sync_buf(bufnr)
		end,
	})

	-- set all the lines in the new buffer
	local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	vim.rpcrequest(M.channel, "nvim_buf_set_lines", connected_bufnr, 0, -1, false, all_lines)

	vim.rpcrequest(M.channel, "nvim_win_set_buf", 0, connected_bufnr)

	-- mark buffer
	vim.api.nvim_buf_set_var(bufnr, "sharing", true)
	vim.api.nvim_buf_set_var(bufnr, "multiplayer_bufnr", connected_bufnr)

	vim.rpcrequest(M.channel, "nvim_buf_set_var", connected_bufnr, "sharing", true)
	vim.rpcrequest(M.channel, "nvim_buf_set_var", connected_bufnr, "multiplayer_bufnr", bufnr)

	M.track_edits(bufnr)
	vim.rpcnotify(M.channel, "nvim_exec_lua", [[return Multiplayer.coop.track_edits(...)]], { connected_bufnr })
end

-- Host calls to sync to the connected client(s)
function M.host_sync_buf(bufnr)
	bufnr = bufnr or 0

	local connected_bufnr = vim.api.nvim_buf_get_var(bufnr, "multiplayer_bufnr")

	-- set all the lines in the new buffer
	local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	vim.rpcrequest(M.channel, "nvim_buf_set_lines", connected_bufnr, 0, -1, false, all_lines)
end

-- Client calls to sync from the host
function M.join_sync_buf(bufnr)
	bufnr = bufnr or 0

	local connected_bufnr = vim.api.nvim_buf_get_var(bufnr, "multiplayer_bufnr")

	local all_lines = vim.rpcrequest(M.channel, "nvim_buf_get_lines", connected_bufnr, 0, -1, false)

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, all_lines)
end

-- takes a table as an argument with the keys
-- type = "lines" | "bytes"
-- start_row
-- start_col
-- end_row
-- end_col
-- content
-- NOTE: unused
function M.apply_edit(edit)
	-- this is definitely not done
	if edit.type == "lines" then
		local content = vim.api.nvim_buf_get_lines(0, edit.start_row, edit.end_row, false)
		local line_count = vim.api.nvim_buf_line_count(0)
		if content == edit.content and line_count == edit.line_count then
			return
		end
		if content ~= edit.content and line_count == edit.line_count then
			vim.api.nvim_buf_set_lines(0, edit.start_row, edit.end_row, false, edit.content)
		end
	end
end

function M.send()
	local message = vim.fn.input("Send a message...")
	vim.rpcnotify(M.channel, "nvim_echo", { { message } }, true, {})
end

function M.notify_send(channel, msg)
	vim.rpcnotify(channel, "nvim_echo", { { msg } }, true, {})
	-- vim.api.nvim_echo({ { "chunk1-line1\nchunk1-line2\n" }, { "chunk2-line1" } }, true, {})
	-- vim.rpcnotify(
	-- 	channel,
	-- 	"nvim_exec_lua",
	-- 	[[return Multiplayer.send_marks(...)]],
	-- 	{ Multiplayer.username, Multiplayer.cursor_ns_id, "MultiplayerCursor" }
	-- )
	-- vim.notify(msg)
end

function M.test_connection(channel)
	M.notify_send(channel, "hello")
end

function M.bufs()
	local all_bufs = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
			local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
			all_bufs[buf] = ft
		end
	end
	vim.print(all_bufs)
end

return M
