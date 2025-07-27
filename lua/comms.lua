local uv = vim.uv

local M = {}

M.group = vim.api.nvim_create_augroup("Comms", { clear = true })

function M.start(role, ticket)
	ticket = ticket or nil
	local port = Multiplayer.rust.port()

	local stdin = uv.new_pipe()
	local stdout = uv.new_pipe()
	local stderr = uv.new_pipe()

	local comms_args = {}

	if role == "host" then
		comms_args = { role, "--addr", "0.0.0.0:" .. port }
	elseif role == "join" then
		comms_args = { role, "--addr", "0.0.0.0:" .. port, ticket }
	end

	local handle, pid = uv.spawn(Multiplayer.rust.comms.path, {
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
			local host_ticket = string.match(data, "ticket:%s(%S+)")

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
