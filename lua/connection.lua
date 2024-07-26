local M = {}

local uv = vim.uv

local client = uv.new_tcp()

local function on_read(err, chunk)
	if err then
		vim.print("Error: " .. err)
		return
	end
	if chunk then
		local decoded = vim.mpack.decode(chunk)
		-- TODO:
		vim.print("Received: " .. chunk)
		local row, col = string.match(chunk, "(%d+),(%d+)")
		if row and col then
			row = tonumber(row)
			col = tonumber(col)
			-- use coords here
		else
			vim.print("Failed to parse coordinates")
		end
	else
		vim.print("Connection closed by server")
		client:close()
	end
end

M.send_data = function(data)
	local encoded = vim.mpack.encode(data)
	client:write(encoded, function(err)
		if err then
			vim.print("Write error: " .. err)
			-- else
			-- 	vim.print("Data sent: " .. data)
		end
	end)
end

client:connect("127.0.0.1", 5111, function(err)
	if err then
		vim.print("Connection error: " .. err)
		return
	end
	vim.print("Connected to server")
	-- send_data("tcp\n")
	client:read_start(on_read)
end)

-- uv.timer_start(uv.new_timer(), 1000, 1000, function()
-- 	send_data("Hello from Lua!\n")
-- end)

uv.run("nowait")

return M
