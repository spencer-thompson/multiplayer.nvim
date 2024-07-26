local M = {}

-- function M.hello_world()
-- 	vim.print("hello world")
-- end

-- function M.setup(opts)
-- 	vim.api.nvim_create_user_command("Multiplayer", M.hello_world, {})
-- end

M.events = {}
M.ns_id = vim.api.nvim_create_namespace("Multiplayer")
M.curpos = { 1, 1 }

M.cursor_ns_id = vim.api.nvim_create_namespace("MultiplayerCursor")

M.setup = function(opts)
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

	vim.api.nvim_create_user_command("Multiplayer", function(args)
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
			-- require("connection")

			-- M.channel_id = vim.fn.sockconnect("tcp", "localhost:5111", {
			-- 	on_data = function()
			-- 		vim.print("Triggered on data")
			-- 	end,
			-- 	rpc = true,
			-- })
			-- local channel_id = vim.fn.sockconnect("tcp", "localhost:5111")

			-- vim.rpcnotify(M.channel_id, "cursor", M.username, vim.api.nvim_win_get_cursor(0))
			-- vim.print(vim.rpcrequest(M.channel_id, "something"))

			-- vim.rpcnotify(M.channel_id, "HandleRequest", M.username, vim.api.nvim_win_get_cursor(0))
			vim.api.nvim_buf_attach(0, false, {

				on_lines = function(lines, buf, ct, fl, ll, ld, m)
					-- table.insert(M.events, { ... })
					-- vim.print(args)

					-- vim.rpcnotify(M.channel_id, "something", vim.api.nvim_buf_get_lines(buf, fl, ld, true))
					-- vim.fn.chansend(M.channel_id, vim.api.nvim_buf_get_lines(buf, fl, ld, true))

					-- for i, s in vim.api.nvim_buf_get_lines(buf, fl, ld, true) do
					-- vim.api.nvim_chan_send(channel_id, s)
					-- vim.api.nvim_chan_send(M.channel_id, s)
					-- end

					-- vim.api.nvim_chan_send(M.channel_id, vim.api.nvim_buf_get_lines(buf, fl, ld, true))
					-- vim.print(vim.api.nvim_buf_get_lines(buf, fl, ld, true))
					-- vim.print(vim.api.nvim_win_get_cursor(0))
					-- vim.api.nvim_chan_send()
					-- vim.validate
				end,
				on_bytes = function(by, buf, ct, srt, sct, boc, oer, oec, oeb, ner, nec, neb)
					vim.print(by, buf, ct, srt, sct, boc, oer, oec, oeb, ner, nec, neb)
					vim.print(vim.api.nvim_buf_get_text(0, oer, oec, ner, nec, {}))
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
