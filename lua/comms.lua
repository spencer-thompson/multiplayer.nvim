local uv = vim.uv

local M = {}

M.group = vim.api.nvim_create_augroup("Comms", { clear = true })

local bin = {
	path = "dumbpipe", -- will change to Multiplayer.rust.comms.path
	host_args = { "listen-tcp", "--host" },
	join_args = { "connect-tcp", "--addr" },
	-- dumbpipe = {
	-- 	path = "dumbpipe",
	-- 	args = {},
	-- },
	-- comms = {
	-- 	path = Multiplayer.rust.comms.path,
	-- 	args = {},
	-- },
}

function M.test()
	local test_list = vim.list_extend(bin.host_args, { "test1", "test2" })
	vim.print(test_list)
end

function M.start(role, ticket)
	ticket = ticket or nil
	local port = Multiplayer.rust.port()
	M.port = port

	local stdin = uv.new_pipe()
	local stdout = uv.new_pipe()
	local stderr = uv.new_pipe()

	local comms_args = {}

	if role == "host" then
		-- comms_args = { role, "--addr", "0.0.0.0:" .. port }
		comms_args = vim.list_extend(bin.host_args, { "0.0.0.0:" .. port })
	elseif role == "join" then
		-- comms_args = { role, "--addr", "0.0.0.0:" .. port, ticket }
		comms_args = vim.list_extend(bin.join_args, { "0.0.0.0:" .. port, ticket })
	end

	local handle, pid = uv.spawn(bin.path, {
		args = comms_args,
		stdio = { stdin, stdout, stderr },
	}, function(code, signal)
		vim.print("exit code", code)
		vim.print("exit signal", signal)
	end)

	vim.print("Started Comms")

	uv.read_start(stderr, function(err, data)
		if data then
			local address = string.match(data, "address:%s(%S+)")
			-- local host_ticket = string.match(data, "ticket:%s(%S+)")
			local host_ticket = string.match(data, "(node%S+)")

			-- vim.print(data)

			M.address = address
			-- vim.print(ticket)
			-- grab the ticket and put it into the unnamed plus register
			vim.schedule(function()
				vim.fn.setreg("+", host_ticket)
			end)
		end
	end)

	vim.api.nvim_create_autocmd("VimLeavePre", {
		desc = "Cleanup Comms",
		pattern = "*",
		callback = function()
			uv.process_kill(M.handle, "sigterm")
		end,
	})

	-- M.address = address
	M.handle = handle
	M.pid = pid
end

return M
