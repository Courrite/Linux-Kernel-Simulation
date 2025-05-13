local constants = require(script.Parent.constants)

local ACTION = {
	TERMINATE = "terminate",  -- kill the process
	IGNORE    = "ignore",     -- drop the signal
}

local signals = {
	queue = {}, -- pending signal queues: pid -> list of pending signal numbers
	handlers = {}, -- installed handlers: pid -> { [signum] = handlerFunction }
	defaultAction = {
		[constants.SIGNALS.SIGHUP]  = ACTION.TERMINATE,
		[constants.SIGNALS.SIGINT]  = ACTION.TERMINATE,
		[constants.SIGNALS.SIGQUIT] = ACTION.TERMINATE,
		[constants.SIGNALS.SIGKILL] = ACTION.TERMINATE,  -- cannot be caught or ignored
		[constants.SIGNALS.SIGTERM] = ACTION.TERMINATE,
		[constants.SIGNALS.SIGCHLD] = ACTION.IGNORE,
		[constants.SIGNALS.SIGUSR1] = ACTION.TERMINATE,
		[constants.SIGNALS.SIGUSR2] = ACTION.TERMINATE,
	}
}

-- callback hooks (to be set by scheduler or kernel core)
-- onTerminate(pid, signum): invoked when a signal's default action is TERMINATE
signals.onTerminate = function(pid, signum)
	-- placeholder; scheduler should override this via SetTerminateCallback
end

function signals:Init()
	self.queue = {}
	self.handlers = {}
end

-- allow external modules (e.g., scheduler) to register a terminate callback
function signals:_setTerminateCallback(fn)
	assert(type(fn) == "function", "Terminate callback must be a function(pid, signum)")
	self.onTerminate = fn
end

-- register a user-defined handler for a specific signal
function signals:RegisterHandler(pid, signum, fn)
	assert(type(pid) == "number", "PID must be a number")
	assert(type(signum) == "number" and constants.SIGNALS[signum], "Invalid signal number")
	assert(type(fn) == "function", "Handler must be a function")

	self.handlers[pid] = self.handlers[pid] or {}
	self.handlers[pid][signum] = fn
end

-- enqueue a signal for a process (asynchronous send)
function signals:Send(pid, signum)
	assert(type(pid) == "number", "PID must be a number")
	assert(type(signum) == "number" and constants.SIGNALS[signum], "Invalid signal number")

	self.queue[pid] = self.queue[pid] or {}
	table.insert(self.queue[pid], signum)
end

-- deliver pending signals for a process; should be called by scheduler or kernel loop
function signals:Deliver(pid)
	local pending = self.queue[pid]
	if not pending then
		return
	end

	local phandlers = self.handlers[pid] or {}
	for _, sig in pending do
		local fn = phandlers[sig]
		if fn then
			fn(sig)
		else
			local action = self.defaultAction[sig] or ACTION.IGNORE
			if action == ACTION.TERMINATE then
				self.onTerminate(pid, sig)
			end
		end
	end

	-- clear delivered signals
	self.queue[pid] = nil
end

return signals
