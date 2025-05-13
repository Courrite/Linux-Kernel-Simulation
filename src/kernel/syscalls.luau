local constants = require(script.Parent.constants)
local syscalls = {
	handlers = {}, -- syscall number -> handler
	names = {}
}

function syscalls:Init()
	self.handlers = {}
	self.names = {}
end

-- register a syscall handler
function syscalls:DefineSyscall(num, name, fn)
	assert(type(num) == "number", "Invalid syscall number")
	assert(type(name) == "string", "Invalid syscall name")
	assert(type(fn) == "function", "Handler must be a function")
	self.handlers[num] = fn
	self.names[num] = name
end

-- dispatch a syscall: returns result or negative errno
function syscalls:Dispatch(pid, num, ...)
	local handler = self.handlers[num]
	if not handler then
		return -constants.ERRNO.ENOSYS
	end
	return handler(pid, ...)
end

-- get human-readable name
function syscalls:GetName(num)
	return self.names[num] or tostring(num)
end

return syscalls
