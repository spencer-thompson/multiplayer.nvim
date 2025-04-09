local Job = require("plenary.job")

local M = {}

function M.host()
	-- test
	local dumbpipe = Job:new({
		command = "dumbpipe",
		args = {
			"listen-tcp",
			"--host",
			"0.0.0.0:6666",
		},
		-- interactive = false,
		on_start = function()
			vim.print("started")
		end,
		on_stdout = function(error, data)
			vim.print(error)
			vim.print(data)
		end,
	})

	dumbpipe:start()

	local channel = vim.fn.sockconnect("tcp", "0.0.0.0:6666", { rpc = true })

	return channel
end

function M.join(ticket)
	local dumbpipe = Job:new({
		command = "dumbpipe",
		args = {
			"connect-tcp",
			"--addr",
			"0.0.0.0:6667",
			ticket,
		},
		on_stdout = function(error, data)
			vim.print(data)
		end,
	})

	dumbpipe:start()

	local channel = vim.fn.sockconnect("tcp", "0.0.0.0:6666", { rpc = true })

	return channel
end

function M.notify_send(channel, msg)
	vim.rpcnotify(channel, "nvim_echo", { { "test\n" }, { "chunk2-line1" } }, true, {})
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

return M
