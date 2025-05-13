local constants = require(script.Parent.Parent.kernel.constants)

local msgqueue = {
	_queues = {} -- key -> queue instance
}
msgqueue.__index = msgqueue

function msgqueue.new(key)
	assert(key ~= nil, "msgqueue.new requires a key")
	if not msgqueue._queues[key] then
		msgqueue._queues[key] = setmetatable({
			id    = key,
			queue = {},  -- list of { type = number, data = any }
		}, msgqueue)
	end
	return msgqueue._queues[key]
end

--- send one message into the queue
function msgqueue:send(msgType, data)
	assert(type(msgType) == "number", "msgType must be a number")
	table.insert(self.queue, { type = msgType, data = data })
	return true
end

--- receive one message (non-blocking)
function msgqueue:receive(requestType)
	for i, msg in self.queue do
		if requestType == 0 or msg.type == requestType then
			table.remove(self.queue, i)
			return msg.type, msg.data
		end
	end
	-- no matching message
	return nil, constants.ERRNO.EAGAIN
end

return msgqueue
