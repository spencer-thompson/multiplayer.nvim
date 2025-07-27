local M = {}

local ffi = require("ffi")

ffi.cdef([[
int get_open_port(void);
]])

local function get_lib_extension()
	if jit.os:lower() == "mac" or jit.os:lower() == "osx" then
		return ".dylib"
	end
	if jit.os:lower() == "windows" then
		return ".dll"
	end
	return ".so"
end

local current_file = debug.getinfo(1, "S").source:sub(2)
local parent_dir = vim.fs.dirname(current_file)
local rust_code_dir = vim.fs.normalize(parent_dir .. "/../comms/target/release/")

local libname = vim.fs.joinpath(rust_code_dir .. "/libcomms" .. get_lib_extension())
-- vim.print(libname)

M.lib = ffi.load(libname)

M.port = function()
	local open_port = M.lib.get_open_port()
	-- vim.print("Open port:", open_port)
	return open_port
end

M.comms = {
	path = vim.fs.joinpath(rust_code_dir .. "/comms"),
}

return M
