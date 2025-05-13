local constants = require(script.Parent.Parent.kernel.constants)

local lsm = {
	hooks = {
		file_open  = {}, -- functions(pid, path, flags) -> bool
		file_read  = {}, -- functions(pid, fd, count) -> bool
		file_write = {}, -- functions(pid, fd, buf) -> bool
	}
}

-- register a hook for a given action
function lsm:RegisterHook(hookName, fn)
	assert(self.hooks[hookName], "Invalid LSM hook: " .. tostring(hookName))
	assert(type(fn) == "function", "Hook must be a function")
	table.insert(self.hooks[hookName], fn)
end

-- run all hooks for an action; deny if any returns false
function lsm:RunHooks(hookName, ...)
	local fns = self.hooks[hookName]
	for _, fn in fns do
		local ok, err = fn(...)
		if not ok then
			return false, err or constants.ERRNO.EACCES
		end
	end
	return true
end

return lsm
