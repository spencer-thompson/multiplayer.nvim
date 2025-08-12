local Multiplayer = {}

Multiplayer.setup = function(opts)
	local state = require("state")

	state.config = vim.tbl_deep_extend("force", state.config, opts or {})

	-- Setup username from config or get git username
	state.config.username = state.config.username
		or vim.trim(vim.system({ "git", "config", "user.name" }, { text = true }):wait().stdout)

	_G.Multiplayer = Multiplayer

	Multiplayer.coop = require("coop")
	Multiplayer.rust = require("rust")
	Multiplayer.comms = require("comms")

	Multiplayer.ns_id = vim.api.nvim_create_namespace("Multiplayer")
	Multiplayer.cursor_ns_id = vim.api.nvim_create_namespace("MultiplayerCursor")

	-- DUMBPIPE
	vim.api.nvim_create_user_command("Coop", function(args)
		if args.fargs[1] == "host" then
			Multiplayer.coop.host()
		end
		if args.fargs[1] == "join" then
			if args.fargs[2] then
				Multiplayer.coop.join(args.fargs[2])
			else
				Multiplayer.coop.join(vim.fn.input("Paste Ticket"))
			end
		end
		if args.fargs[1] == "send" then
			local message = ""
			if #args.fargs >= 2 then
				message = table.concat(args.fargs, " ", 2)
			else
				message = vim.fn.input("Send a message...")
			end
			Multiplayer.coop.send(message)
		end
		if args.fargs[1] == "test" then
			if #args.fargs >= 2 then
				-- vim.print(#args.fargs)
				local message = table.concat(args.fargs, " ", 2)
				vim.print(message)
			end
			if args.fargs[2] then
				vim.print(args.fargs[2])
			end
			require("rust")
		end
		if args.fargs[1] == "share" then
			if args.fargs[2] == nil then
				Multiplayer.coop.share_buf(0)
			end
			if args.fargs[2] == "buf" then
				Multiplayer.coop.share_buf(0)
			end
		end
	end, {
		nargs = "*",

		complete = function(ArgLead, CmdLine, CursorPos)
			-- return completion candidates as a list-like table
			return { "host", "join", "send", "share" }
		end,
	})
end

-- vim.api.nvim_create_user_command("Multiplayer", function(args)
--
-- end, {
-- 	nargs = "*",
-- 	complete = function(ArgLead, CmdLine, CursorPos)
-- 		return { "host", "join", "send", "share" }
-- 	end,
-- })

return Multiplayer
