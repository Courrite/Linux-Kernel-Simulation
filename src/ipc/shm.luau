local constants = require(script.Parent.Parent.kernel.constants)

local shm = {
	_segs = {} -- key -> segment
}
shm.__index  = shm

function shm.new(key, size)
	assert(key ~= nil, "shm.new requires a key")
	assert(type(size) == "number" and size >= 0, "invalid size")
	if not shm._segs[key] then
		shm._segs[key] = setmetatable({
			id   = key,
			size = size,
			data = string.rep("\0", size),
		}, shm)
	end
	return shm._segs[key]
end

--- read from the segment
function shm:read(offset, count)
	if offset < 0 or offset + count > self.size then
		return nil, constants.ERRNO.EFAULT
	end
	return self.data:sub(offset + 1, offset + count)
end

--- write into the segment
function shm:write(offset, buf)
	local n = #buf
	if offset < 0 or offset + n > self.size then
		return nil, constants.ERRNO.EFAULT
	end
	-- splice the new data in
	self.data = 
		self.data:sub(1, offset) ..
		buf ..
		self.data:sub(offset + n + 1)
	return n
end

return shm
