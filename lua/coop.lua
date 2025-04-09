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

	local address = vim.fn.serverstart("0.0.0.0:6666")

	dumbpipe:start()

	local channel = vim.fn.sockconnect("tcp", "0.0.0.0:6666", { rpc = true })

	vim.api.nvim_create_autocmd("ChanInfo", {
		desc = "Detect New Client",
		pattern = "*", -- for now
		group = vim.api.nvim_create_augroup("coop", { clear = true }),
		callback = function(ev)
			-- vim.notify(string.format("clients: %s", vim.inspect(ev)))

			-- local all_clients = vim.rpcrequest(channel, "nvim_list_chans")
			local all_clients = vim.api.nvim_list_chans()
			for _, client in ipairs(all_clients) do
				if client.client and client.client.name then
					if client.client.name == "Multiplayer" then
						vim.print("Connected")
						vim.print("client.id")
						M.channel = client.id
					end
				end
			end
		end,
	})

	-- M.channel = channel

	return channel
end

function M.join(ticket)
	local dumbpipe = Job:new({
		command = "dumbpipe",
		args = {
			"connect-tcp",
			"--addr",
			"0.0.0.0:6668",
			ticket,
		},
		on_stdout = function(error, data)
			vim.print(data)
		end,
		on_stderr = function(error, data)
			vim.print(error)
			vim.print(data)
		end,
	})

	dumbpipe:start()

	local channel = vim.fn.sockconnect("tcp", "0.0.0.0:6668", { rpc = true })

	M.channel = channel

	M.username = vim.system({ "git", "config", "user.name" }, { text = true }):wait().stdout
	M.username = vim.trim(M.username)

	vim.rpcrequest(
		Multiplayer.channel,
		"nvim_set_client_info",
		"Multiplayer",
		{},
		"host",
		{},
		{ git_username = M.username, buf = vim.api.nvim_get_current_buf() }
	)

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
