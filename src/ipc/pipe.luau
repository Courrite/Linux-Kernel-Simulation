local pipe = {}
pipe.__index = pipe

function pipe.new()
	return setmetatable({
		buffer = "",
		readPos = 1,
	}, pipe)
end

function pipe:read(count)
	-- read up to count bytes from buffer
	local available = #self.buffer - self.readPos + 1
	local n = math.min(count, available)
	if n <= 0 then return "" end
	local data = self.buffer:sub(self.readPos, self.readPos + n - 1)
	self.readPos = self.readPos + n
	return data
end

function pipe:write(data)
	self.buffer = self.buffer .. data
	return #data
end

return pipe
