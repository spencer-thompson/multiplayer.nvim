-- Essentially there need to be two autocmds:
-- + one for cursors (location)
-- + one for buffer updates

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

	vim.api.nvim_create_autocmd("VimLeavePre", {
		desc = "Clear Autocmds",
		pattern = "*",
		callback = function()
			vim.fn.chanclose(M.channel)
			vim.api.nvim_del_augroup_by_id(M.group)
			-- vim.api.nvim_clear_autocmds({ group = M.group })
		end,
	})
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
				if ok and M.active then
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
					{ content, remote_bufnr, flc, llc, clientnr }
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

function M.apply_edits(lines, buf, flc, llc, clientnr)
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

-- function M.cleanup()
-- 	vim.api.nvim_create_autocmd("VimLeavePre", {
-- 		desc = "Disconnect Client",
-- 		pattern = "*",
-- 		callback = function()
-- 			vim.rpcnotify(M.channel, "nvim_exec_lua", { M.client_number })
-- 		end,
-- 	})
-- end
--
-- function M.disconnect(clientnr)
-- 	M.connected = false
-- end

function M.host(port)
	M.init()

	Multiplayer.comms.start("host")

	-- local address = vim.fn.serverstart("0.0.0.0:" .. port)
	local address = vim.fn.serverstart("0.0.0.0:" .. Multiplayer.comms.port)

	-- dumbpipe:start()

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

	-- M.dumbpipe = dumbpipe

	-- M.cleanup()
	M.track_cursor()

	vim.print(address)
	return address
end

function M.join(ticket, port)
	M.init()
	M.client_number = 2 -- HACK:

	Multiplayer.comms.start("join", ticket)

	-- we have to wait just a bit for the socket to connect
	vim.defer_fn(function()
		local chan = vim.fn.sockconnect("tcp", "0.0.0.0:" .. Multiplayer.comms.port, { rpc = true })
		-- local chan = vim.fn.sockconnect("tcp", "0.0.0.0:" .. port, { rpc = true })
		vim.print(chan)
		M.channel = chan

		M.on_connect("join")

		-- M.dumbpipe = dumbpipe

		-- M.cleanup()
		M.track_cursor()
	end, 5000)
end

function M.on_connect(role)
	-- M.username = vim.system({ "git", "config", "user.name" }, { text = true }):wait().stdout
	-- M.username = vim.trim(M.username)
	M.notify_send(M.channel, "Connected")

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
	-- M.connected = true
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
		command = "lua Multiplayer.coop.join_sync_buf(0)",
	})

	vim.api.nvim_create_autocmd("BufWritePost", {
		desc = "Sync Buffer on Write",
		buffer = bufnr,
		group = M.group,
		callback = function()
			-- if M.connected then
			M.host_sync_buf(bufnr)
			-- end
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

	-- function M.apply_edits(lines, buf, flc, llc, clientnr)
	--

	local connected_bufnr = vim.api.nvim_buf_get_var(bufnr, "multiplayer_bufnr")

	-- set all the lines in the new buffer
	local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local clientnr = M.client_number
	-- vim.rpcrequest(M.channel, "nvim_buf_set_lines", connected_bufnr, 0, -1, false, all_lines)

	vim.rpcrequest(
		M.channel,
		"nvim_exec_lua",
		[[return Multiplayer.coop.apply_edits(...)]],
		{ all_lines, connected_bufnr, 0, -1, clientnr }
	)
end

-- Client calls to sync from the host
function M.join_sync_buf(bufnr)
	bufnr = bufnr or 0

	local connected_bufnr = vim.api.nvim_buf_get_var(bufnr, "multiplayer_bufnr")

	local all_lines = vim.rpcrequest(M.channel, "nvim_buf_get_lines", connected_bufnr, 0, -1, false)

	M.last_edit.client_number = -1
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, all_lines)

	vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
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
