local panic = {
	called  = false,
	onPanic = function() end,  -- will be set by kernel/init
}

local startTime = os.clock()

local function uptime()
	return string.format("%.6f", os.clock() - startTime)
end

local function stackTrace()
	return debug.traceback("[ Call Trace ]", 3)
end

--- set a callback to run after we logged panic but before halting
function panic:SetHandler(fn)
	assert(type(fn) == "function", "panic handler must be a function")
	self.onPanic = fn
end

function panic:Fail(msg)
	if self.called then return end
	self.called = true

	local PanicEvent = script.Parent.Parent.events.Panic
	PanicEvent:Fire(tostring(msg))

	local banner = ("="):rep(60)
	warn(banner)
	warn(("[ %s] Kernel panic: %s")
		:format(uptime(), tostring(msg)))
	warn(stackTrace())
	warn(("[ %s] ---[ end Kernel panic: %s ]---")
		:format(uptime(), tostring(msg)))
	warn(banner)

	pcall(self.onPanic)
end

return panic
