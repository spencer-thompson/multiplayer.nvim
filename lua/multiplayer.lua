local M = {}

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
		end
		-- if args.fargs[1] == "show" then
		-- 	vim.print(M.events)
		-- end
		if args.fargs[1] == "stop" then
			vim.api.nvim_clear_autocmds({ group = "Multiplayer" })
		end
		if args.fargs[1] == "test" then
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
				-- TODO: the thing
			end)
			-- M.websocket:start()

			M.autocmd_group = vim.api.nvim_create_augroup("Multiplayer", { clear = true })
			vim.api.nvim_create_autocmd("BufEnter", {
				desc = "Track Buffer Change",
				pattern = "*", -- for now
				group = M.autocmd_group,
				callback = function()
					-- TODO: ask user if they want to add new buffer
					local buf = vim.api.nvim_get_current_buf()
					local fname = vim.api.nvim_buf_get_name(0)

					local encoded_data = vim.json.encode({
						usr = M.username,
						buf = buf,
						fname = fname,
					})
					websocket_send:write({ encoded_data })
				end,
			})

			vim.api.nvim_create_autocmd("CursorMoved", {
				desc = "Track Cursor Movement",
				pattern = "*", -- for now
				group = M.autocmd_group,
				callback = function()
					local curpos = vim.api.nvim_win_get_cursor(0)
					local buf = vim.api.nvim_get_current_buf()

					local encoded_pos = vim.json.encode({
						usr = M.username,
						buf = buf,
						cur = { row = curpos[1], col = curpos[2] },
					})
					-- vim.print(encoded_pos)
					websocket_send:write({ encoded_pos })
				end,
			})

			vim.api.nvim_buf_attach(0, false, {

				on_bytes = function(byt, buf, ct, sr, sc, bo, oR, oc, ob, nr, nc, nb)
					websocket_send:write({ vim.json.encode({ sr, sc, oR, oc, nr, nc }) })
					if nr < oR or nc < oc then
						local encoded_data = vim.json.encode({
							usr = M.username,
							buf = buf,
							del = { row = { sr, sr - oR }, col = { sc, sc - oc } },
						})
						websocket_send:write({ encoded_data })
					else
						local new_text = vim.api.nvim_buf_get_text(buf, sr, sc, sr + nr, sc + nc, {})
						local encoded_data = vim.json.encode({
							usr = M.username,
							buf = buf,
							text = new_text,
							row = { sr, sr + nr },
							col = { sc, sc + nc },
						})
						websocket_send:write({ encoded_data })
					end
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
