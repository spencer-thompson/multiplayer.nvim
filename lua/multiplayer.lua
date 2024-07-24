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

M.autocmd_group = vim.api.nvim_create_augroup("Multiplayer Tracking", { clear = true })

M.setup = function(opts)
	vim.api.nvim_create_user_command("Multiplayer", function(opts)
		-- print(string.upper(opts.fargs[1]))
		if opts.fargs[1] == "connect" then
			vim.api.nvim_buf_attach(0, true, {
				on_lines = function(lines, buf, ct, fl, ll, ld, m)
					-- if args[1] == "lines" then
					-- 	vim.print("Lines!!!")
					-- end
					-- table.insert(M.events, { ... })
					-- vim.print(args)
					-- vim.print(vim.api.nvim_buf_get_lines(buf, fl, ld, true))
					vim.print(vim.api.nvim_win_get_cursor(0))
				end,
			})
			vim.api.nvim_create_autocmd("CursorMoved", {
				desc = "Track Cursor Movement",
				pattern = "*.md", -- for now
				group = M.autocmd_group,
				callback = function()
					vim.print(vim.api.nvim_win_get_cursor(0))
					vim.api.nvim_buf_clear_namespace(0, M.ns_id, 0, -1)
					M.curpos = vim.api.nvim_win_get_cursor(0)
					vim.api.nvim_buf_add_highlight(
						0,
						M.ns_id,
						"IncSearch",
						M.curpos[1] - 1,
						M.curpos[2],
						M.curpos[2] + 1
					)
				end,
			})
		end
		if opts.fargs[1] == "show" then
			vim.print(M.events)
		end
		-- if opts.fargs[1] == "disconnect" then
		-- 	vim.api.nvim_buf_detach
		-- end
	end, {
		nargs = 1,
		complete = function(ArgLead, CmdLine, CursorPos)
			-- return completion candidates as a list-like table
			return { "connect", "show", "baz" }
		end,
	})
end

return M
