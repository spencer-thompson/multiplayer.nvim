local M = {}

M.events = {}
M.ns_id = vim.api.nvim_create_namespace("Multiplayer")
M.curpos = { 1, 1 }

M.cursor_ns_id = vim.api.nvim_create_namespace("MultiplayerCursor")

M.setup = function(opts)
	M.socket_address = vim.fn.serverstart("websocket")

	-- highlight groups | see :h guifg
	vim.api.nvim_set_hl(M.cursor_ns_id, "MultiplayerCursor1", { fg = "NvimLightBlue" })
	vim.api.nvim_set_hl(M.cursor_ns_id, "MultiplayerCursor2", { fg = "NvimLightCyan" })
	vim.api.nvim_set_hl(M.cursor_ns_id, "MultiplayerCursor3", { fg = "NvimLightGreen" })
	vim.api.nvim_set_hl(M.cursor_ns_id, "MultiplayerCursor4", { fg = "NvimLightMagenta" })
	vim.api.nvim_set_hl(M.cursor_ns_id, "MultiplayerCursor5", { fg = "NvimLightRed" })
	vim.api.nvim_set_hl(M.cursor_ns_id, "MultiplayerCursor6", { fg = "NvimLightYellow" })

	-- M.username = vim.api.nvim_cmd({ "git", "config", "user.name" }, { output = true })
	M.username = vim.system({ "git", "config", "user.name" }, { text = true }):wait().stdout
	M.username = vim.trim(M.username)

	vim.api.nvim_create_user_command("Multi", function(args)
		if args.fargs[1] == "connect" then
			M.channel_id = vim.fn.sockconnect("tcp", "localhost:5112", { rpc = true })
			local conn = require("connection")
			-- conn.send_data(M.username .. "\n")
			vim.rpcnotify(M.channel_id, "user", M.username)

			-- get every buffer
			-- check if buffer is "in" git repo
			-- first to connect set git ref
			vim.api.nvim_buf_attach(0, true, {
				on_lines = function(lines, buf, ct, fl, ll, ld, m)
					-- TODO: send info via socket
					-- table.insert(M.events, { ... })
					-- vim.print(args)
					-- vim.print(vim.api.nvim_buf_get_lines(buf, fl, ld, true))
					vim.print(vim.api.nvim_win_get_cursor(0))
					-- vim.api.nvim_chan_send()
					-- vim.validate
				end,
			})

			M.autocmd_group = vim.api.nvim_create_augroup("Multiplayer Tracking", { clear = true })
			vim.api.nvim_create_autocmd("CursorMoved", {
				desc = "Track Cursor Movement",
				pattern = "*.md", -- for now
				group = M.autocmd_group,
				callback = function()
					local curpos = vim.api.nvim_win_get_cursor(0)
					vim.rpcnotify(M.channel_id, "cursor", M.username, curpos[1], curpos[2])
					-- if (#vim.api.nvim_win_get_cursor(0)) < 2 then
					-- 	return
					-- else
					-- 	vim.print(table.concat(vim.api.nvim_win_get_cursor(0), ","))
					-- 	conn.send_data(M.username .. "," .. table.concat(vim.api.nvim_win_get_cursor(0), ",") .. "\n")
					-- end
					-- vim.api.nvim_buf_clear_namespace(0, M.ns_id, 0, -1)
					-- M.curpos = vim.api.nvim_win_get_cursor(0)
					-- vim.api.nvim_buf_add_highlight(
					-- 	0,
					-- 	M.ns_id,
					-- 	"IncSearch",
					-- 	M.curpos[1] - 1,
					-- 	M.curpos[2],
					-- 	M.curpos[2] + 1
					-- )
					-- vim.api.nvim_buf_set_extmark(0, M.ns_id, M.curpos[1], M.curpos[2], { end_col = M.curpos[2] + 1 })
				end,
			})
		end
		if args.fargs[1] == "show" then
			vim.print(M.events)
		end
		if args.fargs[1] == "test" then
			-- M.websocket:start()
			local websocket_send = vim.system(
				{ "websocat", "ws://localhost:1234" },
				{ text = false, stdin = true },
				function(obj)
					vim.cmd([[echo "closed"]])
				end
			)

			vim.system({ "websocat", "ws://localhost:1235" }, {
				text = false,
				stdin = true,
				stdout = function(err, data)
					vim.print(err)
					vim.print(data)
					-- vim.print({ data })
				end,
			}, function()
				vim.cmd([[echo "recieve closed"]])
			end)
			-- M.websocket:start()

			M.autocmd_group = vim.api.nvim_create_augroup("Multiplayer Tracking", { clear = true })
			vim.api.nvim_create_autocmd("CursorMoved", {
				desc = "Track Cursor Movement",
				pattern = "*", -- for now
				group = M.autocmd_group,
				callback = function()
					local curpos = vim.api.nvim_win_get_cursor(0)

					local encoded_pos = vim.json.encode({ cur = { row = curpos[1], col = curpos[2] } })
					-- vim.print(encoded_pos)
					websocket_send:write({ encoded_pos })
				end,
			})

			vim.api.nvim_buf_attach(0, false, {

				-- on_lines = function(lines, buf, ct, fl, ll, ld, m)
				-- on_lines = function(...)
				-- 	-- vim.rpcnotify(M.channel_id, "on_lines", { ... })
				-- 	-- M.websocket:send({ ... })
				-- 	local encoded_data = vim.json.encode({ ... })
				-- 	websocket_send:write({ encoded_data })
				-- 	table.insert(M.events, { ... })
				-- end,
				on_bytes = function(byt, buf, ct, sr, sc, bo, oR, oc, ob, nr, nc, nb)
					-- local encoded_data = vim.json.encode({ ... })

					websocket_send:write({ vim.json.encode({ sr, sc, oR, oc, nr, nc }) })
					if nr < oR or nc < oc then
						local encoded_data = vim.json.encode({ del = { row = { sr, sr - oR }, col = { sc, sc - oc } } })
						websocket_send:write({ encoded_data })
					else
						local new_text = vim.api.nvim_buf_get_text(buf, sr, sc, sr + nr, sc + nc, {})
						local encoded_data =
							vim.json.encode({ text = new_text, row = { sr, sr + nr }, col = { sc, sc + nc } })
						websocket_send:write({ encoded_data })
					end
					-- table.insert(M.events, { ... })
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
end

return M
