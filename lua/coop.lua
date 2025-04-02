local Job = require("plneary.job")

local M = {}

function M.host()
	-- test
	local dumbpipe = Job:new({
		command = "dumbpipe",
		args = {
			"listen-tcp",
			"--addr",
			"0.0.0.0:6666",
		},
	})

	local channel = vim.fn.sockconnect("tcp", "0.0.0.0:6666", { rpc = true })

	return channel
end

function M.join(ticket)
	local dumbpipe = Job:new({
		command = "dumbpipe",
		args = {
			"connect-tcp",
			"--addr",
			"0.0.0.0:6666",
			ticket,
		},
	})

	local channel = vim.fn.sockconnect("tcp", "0.0.0.0:6666", { rpc = true })

	return channel
end

function M.notify_send(channel, msg)
	vim.rpcnotify(
		channel,
		"nvim_exec_lua",
		[[return Multiplayer.send_marks(...)]],
		{ Multiplayer.username, Multiplayer.cursor_ns_id, "MultiplayerCursor" }
	)
	vim.notify(msg)
end

return M
