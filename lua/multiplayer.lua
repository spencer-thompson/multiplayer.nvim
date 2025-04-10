local M = {}
local Multiplayer = {}

Multiplayer.ns_id = vim.api.nvim_create_namespace("Multiplayer")
Multiplayer.curpos = { 1, 1 }

Multiplayer.cursor_ns_id = vim.api.nvim_create_namespace("MultiplayerCursor")

Multiplayer.mark_options = { "a", "s", "d", "f" }
Multiplayer.used_marks = {}
Multiplayer.players = {}

Multiplayer.coop = require("coop")

-- Multiplayer.channel = nil

Multiplayer.next_unused_mark = function()
	for _, m in ipairs(Multiplayer.mark_options) do
		if not Multiplayer.used_marks[m] then
			Multiplayer.used_marks[m] = true
			return m
		end
	end
	return nil
end

Multiplayer.setup = function(opts)
	_G.Multiplayer = Multiplayer
	-- Multiplayer.socket_address = vim.fn.serverstart("websocket")

	-- highlight groups | see :h guifg
	-- vim.api.nvim_set_hl(0, "MultiplayerCursor", { link = "Cursor" })
	vim.api.nvim_set_hl(0, "MultiplayerCursor", { bg = "green" })
	vim.api.nvim_set_hl(Multiplayer.cursor_ns_id, "MultiplayerCursor1", { fg = "white", bg = "white" })
	vim.api.nvim_set_hl(Multiplayer.cursor_ns_id, "MultiplayerCursor2", { fg = "NvimLightCyan" })
	vim.api.nvim_set_hl(Multiplayer.cursor_ns_id, "MultiplayerCursor3", { fg = "NvimLightGreen" })
	vim.api.nvim_set_hl(Multiplayer.cursor_ns_id, "MultiplayerCursor4", { fg = "NvimLightMagenta" })
	vim.api.nvim_set_hl(Multiplayer.cursor_ns_id, "MultiplayerCursor5", { fg = "NvimLightRed" })
	vim.api.nvim_set_hl(Multiplayer.cursor_ns_id, "MultiplayerCursor6", { fg = "NvimLightYellow" })

	-- Multiplayer.username = vim.api.nvim_cmd({ "git", "config", "user.name" }, { output = true })
	--

	-- DUMBPIPE
	vim.api.nvim_create_user_command("COOP", function(args)
		if args.fargs[1] == "host" then
			Multiplayer.coop.host()
		end
		if args.fargs[1] == "join" then
			Multiplayer.coop.join(vim.fn.input("Paste Ticket"))
		end
		if args.fargs[1] == "send" then
			Multiplayer.coop.send()
		end
	end, {
		nargs = 1,

		complete = function(ArgLead, CmdLine, CursorPos)
			-- return completion candidates as a list-like table
			return { "host", "join", "send" }
		end,
	})
	-- DUMBPIPE

	vim.api.nvim_create_user_command("Multiplayer", function(args)
		-- if args.fargs[1] == "show" then
		-- 	vim.print(Multiplayer.events)
		-- end
		-- if args.fargs[1]

		if args.fargs[1] == "stop" then
			vim.api.nvim_clear_autocmds({ group = "Multiplayer" })
		end

		if args.fargs[1] == "host" then
			Multiplayer.username = vim.system({ "git", "config", "user.name" }, { text = true }):wait().stdout
			Multiplayer.username = vim.trim(Multiplayer.username)

			Multiplayer.channel = vim.fn.sockconnect("tcp", "127.0.0.1:6666", { rpc = true })
			print(Multiplayer.channel)

			local all_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			vim.rpcrequest(Multiplayer.channel, "nvim_buf_set_lines", 0, 0, -1, false, all_lines)

			-- local filename = vim.api.nvim_buf_get_name(0)
			-- vim.rpcrequest(channel, "nvim_buf_set_name", 0, filename)

			-- Multiplayer.players = vim.rpcrequest(channel, "nvim_list_chans")

			-- for _, c in ipairs(Multiplayer.players) do
			-- 	if c.client and c.client.name then
			-- 		if c.client.name == "Multiplayer" then
			-- 			Multiplayer.used_marks[c.client.attributes.mark] = true
			-- 		end
			-- 	end
			-- end
			--
			-- local next_mark = Multiplayer.next_unused_mark()

			vim.rpcrequest(
				Multiplayer.channel,
				"nvim_set_client_info",
				"Multiplayer",
				{},
				"host",
				{},
				{ git_username = Multiplayer.username, buf = vim.api.nvim_get_current_buf() }
			)

			local filetype = vim.api.nvim_get_option_value("filetype", { buf = 0 })
			vim.rpcrequest(Multiplayer.channel, "nvim_set_option_value", "filetype", filetype, { buf = 0 })

			vim.api.nvim_create_autocmd("CursorMoved", {
				desc = "Track Cursor Movement",
				pattern = "*", -- for now
				group = Multiplayer.autocmd_group,
				callback = function()
					local curpos = vim.api.nvim_win_get_cursor(0)

					vim.rpcnotify(
						Multiplayer.channel,
						"nvim_buf_set_mark",
						0,
						string.sub(Multiplayer.username, 1, 1):lower(),
						curpos[1],
						curpos[2],
						{}
					)
					vim.rpcnotify(
						Multiplayer.channel,
						"nvim_exec_lua",
						[[return Multiplayer.send_marks(...)]],
						{ Multiplayer.username, Multiplayer.cursor_ns_id, "MultiplayerCursor" }
					)
				end,
			})

			vim.api.nvim_buf_attach(0, true, {
				-- on_lines = function(lines, buf, cgt, flc, llc, llu, bcp)
				-- 	local content = vim.api.nvim_buf_get_lines(buf, flc, llc, false)
				-- 	vim.rpcnotify(channel, "nvim_buf_set_lines", 0, flc, llc, false, content)
				-- end,
				on_changedtick = function(changed_tick, buf, cgt)
					local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
					vim.rpcnotify(Multiplayer.channel, "nvim_buf_set_lines", 0, 0, -1, false, content)
				end,
				on_bytes = function(bytes, buf, cgt, srow, scol, bofc, oerow, oecol, oeblc, nerow, necol, neblc)
					local content = vim.api.nvim_buf_get_text(buf, srow, scol, srow + nerow, scol + necol, {})
					vim.rpcnotify(
						Multiplayer.channel,
						"nvim_buf_set_text",
						0,
						srow,
						scol,
						srow + oerow,
						scol + oecol,
						content
					)
				end,
				on_reload = function(reload, buf)
					local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
					vim.rpcnotify(Multiplayer.channel, "nvim_buf_set_lines", 0, 0, -1, false, content)
				end,
			})
		end
		if args.fargs[1] == "server" then
			print("hello world")

			vim.api.nvim_create_autocmd("ChanInfo", {
				desc = "Detect New Client",
				pattern = "*", -- for now
				group = Multiplayer.autocmd_group,
				callback = function(ev)
					print(string.format("event fired: %s", vim.inspect(ev)))
				end,
			})
		end
		-- if opts.fargs[1] == "disconnect" then
		-- 	vim.api.nvim_buf_detach
		-- end
	end, {
		nargs = 1,
		complete = function(ArgLead, CmdLine, CursorPos)
			-- return completion candidates as a list-like table
			return { "connect", "show", "test" }
		end,
	})
	vim.api.nvim_create_user_command("MultiplayerServer", function(args)
		if args.fargs[1] == "start" then
			print("hello")
		end
	end, {
		nargs = 1,
		complete = function(ArgLead, CmdLine, CursorPos)
			return { "start" }
		end,
	})
end

-- Connect to server
Multiplayer.connect = function(address) --address is a string
	Multiplayer.channel = vim.fn.sockconnect("tcp", "127.0.0.1:6666", { rpc = true })

	Multiplayer.username = vim.system({ "git", "config", "user.name" }, { text = true }):wait().stdout
	Multiplayer.username = vim.trim(Multiplayer.username)

	vim.rpcrequest(
		Multiplayer.channel,
		"nvim_set_client_info",
		"Multiplayer",
		{},
		"host",
		{},
		{ git_username = Multiplayer.username, buf = vim.api.nvim_get_current_buf() }
	)

	vim.api.nvim_create_autocmd("CursorMoved", {
		desc = "Track Cursor Movement",
		pattern = "*", -- for now
		group = Multiplayer.autocmd_group,
		callback = function()
			local curpos = vim.api.nvim_win_get_cursor(0)

			vim.rpcnotify(
				Multiplayer.channel,
				"nvim_buf_set_mark",
				0,
				string.sub(Multiplayer.username, 1, 1):lower(),
				curpos[1],
				curpos[2],
				{}
			)
			vim.rpcnotify(
				Multiplayer.channel,
				"nvim_exec_lua",
				[[return Multiplayer.send_marks(...)]],
				{ Multiplayer.username, Multiplayer.cursor_ns_id, "MultiplayerCursor" }
			)
		end,
	})

	vim.rpcrequest(Multiplayer.channel, "nvim_exec_lua", [[return Multiplayer.updates(...)]], { Multiplayer.username })

	-- vim.api.nvim_buf_attach(0, false, {
	-- 	-- on_lines = function(lines, buf, cgt, flc, llc, llu, bcp)
	-- 	-- 	local content = vim.api.nvim_buf_get_lines(buf, flc, llc, false)
	-- 	-- 	vim.rpcnotify(channel, "nvim_buf_set_lines", 0, flc, llc, false, content)
	-- 	-- end,
	-- 	on_changedtick = function(changed_tick, buf, cgt)
	-- 		local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	-- 		vim.rpcnotify(Multiplayer.channel, "nvim_buf_set_lines", 0, 0, -1, false, content)
	-- 	end,
	-- 	on_bytes = function(bytes, buf, cgt, srow, scol, bofc, oerow, oecol, oeblc, nerow, necol, neblc)
	-- 		local content = vim.api.nvim_buf_get_text(buf, srow, scol, srow + nerow, scol + necol, {})
	-- 		vim.rpcnotify(Multiplayer.channel, "nvim_buf_set_text", 0, srow, scol, srow + oerow, scol + oecol, content)
	-- 	end,
	-- 	on_reload = function(reload, buf)
	-- 		local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	-- 		vim.rpcnotify(Multiplayer.channel, "nvim_buf_set_lines", 0, 0, -1, false, content)
	-- 	end,
	-- })
end

-- need to call connect() first
Multiplayer.host = function()
	-- Multiplayer.connect()
	local all_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	vim.rpcrequest(Multiplayer.channel, "nvim_buf_set_lines", 0, 0, -1, false, all_lines)

	local filetype = vim.api.nvim_get_option_value("filetype", { buf = 0 })
	vim.rpcrequest(Multiplayer.channel, "nvim_set_option_value", "filetype", filetype, { buf = 0 })

	local filename = vim.fn.expand("%:t")
	vim.rpcrequest(Multiplayer.channel, "nvim_buf_set_name", 0, filename)
end

Multiplayer.join = function(opts)
	local buf = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_win_set_buf(0, buf)
	vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf })

	local lines = vim.rpcrequest(Multiplayer.channel, "nvim_buf_get_lines", 0, 0, -1, false)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

-- Multiplayer.text_updates = function(username, buf, start_row, start_col, end_row, end_col, content)
-- 	vim.api.nvim_buf_set_text(buf, start_row, start_col, end_row, end_col, content)

-- for name, player in pairs(Multiplayer.players) do
-- 	if not name == username then
-- 		vim.rpcrequest(player.id, "nvim_buf_set_text", buf, start_)
-- 	end
-- end
-- end

Multiplayer.updates_to_server = function() end

Multiplayer.updates_to_client = function() end

Multiplayer.updates = function(username)
	vim.rpcrequest(Multiplayer[username].id, "nvim_buf_attach", Multiplayer[username].buf, false, {
		on_lines = function(...)
			vim.notify("on_lines")
		end,
	})
end

Multiplayer.test = function()
	Multiplayer.username = "Test"

	-- vim.notify(Multiplayer.players)
	-- vim.notify(string.format("clients: %s", vim.inspect(Multiplayer.players)))
end

Multiplayer.send_marks = function(username, ns_id, hl)
	-- vim.print(vim.api.nvim_buf_get_mark(0, "s"))
	for name, player in pairs(Multiplayer.players) do
		-- if not c.client.attributes.git_username == username then
		-- vim.rpcnotify(player.id, "nvim_buf_clear_namespace", player.buf, ns_id, 0, -1)
		-- vim.api.nvim_buf_clear_namespace(0, Multiplayer.cursor_ns_id, 0, -1)
		if not name == username then
			local markpos = vim.api.nvim_buf_get_mark(0, player.mark)
			vim.print(markpos[1])
			vim.rpcrequest(player.id, "nvim_buf_set_mark", player.buf, player.mark, markpos[1], markpos[2], {})
			vim.rpcrequest(
				player.id,
				"nvim_buf_set_extmark",
				player.buf,
				ns_id,
				markpos[1] - 1,
				markpos[2] - 1, -- remove minus one for testing
				{ hl_group = hl, end_col = markpos[2] + 1, id = player.id }
			)
		end

		-- end
	end
end

Multiplayer.send_data = function(username)
	-- for _, c in ipairs(Multiplayer.players) do
	-- 	if not c.client.attributes.git_username == username then
	-- 	end
	-- end
	vim.api.nvim_buf_attach(0, false, {
		-- on_lines = function(lines, buf, cgt, flc, llc, llu, bcp)
		-- 	local content = vim.api.nvim_buf_get_lines(buf, flc, llc, false)
		-- 	vim.rpcnotify(channel, "nvim_buf_set_lines", 0, flc, llc, false, content)
		-- end,
		on_changedtick = function(changed_tick, buf, cgt)
			for name, player in pairs(Multiplayer.players) do
				if not player.username == username then
					local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
					vim.rpcnotify(player.id, "nvim_buf_set_lines", 0, 0, -1, false, content)
				end
			end
		end,
		on_bytes = function(bytes, buf, cgt, srow, scol, bofc, oerow, oecol, oeblc, nerow, necol, neblc)
			for name, player in pairs(Multiplayer.players) do
				if not player.username == username then
					local content = vim.api.nvim_buf_get_text(buf, srow, scol, srow + nerow, scol + necol, {})
					vim.rpcnotify(player.id, "nvim_buf_set_text", 0, srow, scol, srow + oerow, scol + oecol, content)
				end
			end
		end,
		on_reload = function(reload, buf)
			for name, player in pairs(Multiplayer.players) do
				if not player.username == username then
					local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
					vim.rpcnotify(player.id, "nvim_buf_set_lines", player.buf, 0, -1, false, content)
				end
			end
		end,
	})
	-- for _, c in ipairs()
end

Multiplayer.sync = function(players)
	for name, player in pairs(players) do
		Multiplayer.players[name] = player
	end
end

Multiplayer.server = function()
	vim.api.nvim_create_autocmd("ChanInfo", {
		desc = "Detect New Client",
		pattern = "*", -- for now
		group = Multiplayer.autocmd_group,
		callback = function(ev)
			-- vim.notify(string.format("clients: %s", vim.inspect(ev)))

			-- local all_clients = vim.rpcrequest(channel, "nvim_list_chans")
			local all_clients = vim.api.nvim_list_chans()
			for _, client in ipairs(all_clients) do
				if client.client and client.client.name then
					if client.client.name == "Multiplayer" then
						-- if client.client.attributes.git_username = Multiplayer.players.client.attributes.git_username then
						--
						--
						-- end
						client.mark = string.sub(client.client.attributes.git_username, 1, 1):lower()
						Multiplayer.players[client.client.attributes.git_username] = {
							id = client.id,
							buf = client.client.attributes.buf,
							mark = client.mark,
							type = client.client.type,
							username = client.client.attributes.git_username,
						}
						-- local player = {
						-- 	id = client.id,
						-- 	buf = client.client.attributes.buf,
						-- 	mark = client.mark,
						-- 	type = client.client.type,
						-- 	username = client.client.attributes.git_username,
						-- }
						-- Multiplayer.players[player.name] = player
						-- table.insert(Multiplayer.players, player)
						-- table.insert(Multiplayer.players, client)
						-- vim.rpcrequest(client.id, "nvim_exec_lua", [[return Multiplayer.]])
					end
				end
			end

			for name, player in pairs(Multiplayer.players) do
				local res = vim.rpcrequest(player.id, "nvim_buf_attach", player.buf, false, {
					-- on_lines = function(lines, buf, cgt, flc, llc, llu, bcp)
					-- 	local content = vim.api.nvim_buf_get_lines(buf, flc, llc, false)
					-- 	vim.rpcnotify(channel, "nvim_buf_set_lines", 0, flc, llc, false, content)
					-- end,
					on_changedtick = function(changed_tick, buf, cgt)
						-- local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
						-- vim.rpcnotify(Multiplayer.channel, "nvim_buf_set_lines", 0, 0, -1, false, content)
					end,
					on_bytes = function(bytes, buf, cgt, srow, scol, bofc, oerow, oecol, oeblc, nerow, necol, neblc)
						vim.notify("on bytes")
						-- local content = vim.api.nvim_buf_get_text(buf, srow, scol, srow + nerow, scol + necol, {})
						-- vim.rpcnotify(
						-- 	Multiplayer.channel,
						-- 	"nvim_buf_set_text",
						-- 	0,
						-- 	srow,
						-- 	scol,
						-- 	srow + oerow,
						-- 	scol + oecol,
						-- 	content
						-- )
					end,
					on_reload = function(reload, buf)
						-- local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
						-- vim.rpcnotify(Multiplayer.channel, "nvim_buf_set_lines", 0, 0, -1, false, content)
					end,
				})
			end
			-- for _, player in pairs(Multiplayer.players) do
			-- 	vim.rpcrequest(player.id, "nvim_exec_lua", [[return Multiplayer.sync(...)]], { Multiplayer.players })
			-- end

			-- vim.print(ev)
			-- vim.print(Multiplayer.players)
			vim.notify(string.format("event: %s\n\nclients: %s", vim.inspect(ev), vim.inspect(Multiplayer.players)))
			-- vim.print(vim.inspect(Multiplayer.players))
			-- Multiplayer.players = vim.rpcrequest(channel, "nvim_list_chans")
			-- vim.notify(string.format("event fired: %s", vim.inspect(ev)))
		end,
	})
end

return Multiplayer
