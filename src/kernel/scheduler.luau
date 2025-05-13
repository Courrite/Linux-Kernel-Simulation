local constants = require(script.Parent.constants)
local signals = require(script.Parent.signals)
local process = require(script.Parent.process)
local panic = require(script.Parent.panic)

local scheduler = {
	tasks = {}, -- pid -> Process instance
	readyQueue = {}, -- list of pids ready to run
	nextPid = 1,
	currentPid = nil,
	exitStatuses = {}, -- pid -> { childPid = exitCode }
}

function scheduler:Init()
	self.tasks = {}
	self.readyQueue = {}
	self.nextPid = 1
	self.currentPid = nil
	self.exitStatuses = {}

	signals:_setTerminateCallback(function(pid, sig)
		self:KillProcess(pid)
	end)
end

function scheduler:CreateProcessFrom(proc)
	assert(type(proc) == "table" and proc.resume, "Must pass a Process")
	self.tasks[proc.pid] = proc
	table.insert(self.readyQueue, proc.pid)
	return proc.pid
end

function scheduler:Fork(parentPid)
	local parent = self.tasks[parentPid]
	if not parent then return nil, constants.ERRNO.EINVAL end

	local childPid = self.nextPid
	self.nextPid += 1
	
	local child = parent:clone(childPid)
	return self:CreateProcessFrom(child)
end

function scheduler:Exit(pid, code)
	self:KillProcess(pid, code or 0)
end

function scheduler:ExitGroup(pid, code)
	local p = self.tasks[pid]
	if not p then return end

	local pg = p.pgid or pid
	for tpid, proc in self.tasks do
		if proc.pgid == pg then
			self:KillProcess(tpid, code or 0)
		end
	end
end

function scheduler:KillProcess(pid, exitCode)
	if pid == 1 or pid == 0 then
		panic:Fail(pid == 1 and "Attempted to kill init!" or "Attempted to kill idle!")
		return
	end

	self.tasks[pid] = nil

	for i, q in self.readyQueue do
		if q == pid then
			table.remove(self.readyQueue, i)
			break
		end
	end

	if self.currentPid == pid then
		self.currentPid = nil
	end

	-- save exit status for reaping
	for ppid, proc in self.tasks do
		local pg = proc.pgid or ppid
		if pg == pid then
			self.exitStatuses[ppid] = self.exitStatuses[ppid] or {}
			self.exitStatuses[ppid][pid] = exitCode or 0
		end
	end
end

function scheduler:Wait4(pid, pid_wait, statusPtr, options)
	local st = self.exitStatuses[pid] or {}
	for childPid, exitCode in st do
		if pid_wait == 0 or pid_wait == childPid then
			st[childPid] = nil
			return childPid, exitCode
		end
	end

	return nil, constants.ERRNO.ECHILD
end

function scheduler:Schedule()
	-- re-enqueue current if still alive
	if self.currentPid then
		local cur = self.tasks[self.currentPid]
		if cur then
			table.insert(self.readyQueue, self.currentPid)
		end
	end

	local pid = table.remove(self.readyQueue, 1)
	if not pid then return end

	self.currentPid = pid
	signals:Deliver(pid)

	local proc = self.tasks[pid]
	if not proc then return end

	local ok, alive = pcall(function()
		return proc:resume()
	end)

	if not ok then
		warn(("Process %d crashed: %s"):format(pid, tostring(alive)))
		self:KillProcess(pid)
	elseif not alive then
		self:KillProcess(pid)
	end
end

function scheduler:GetCurrentPid()
	return self.currentPid
end

function scheduler:GetProcess(pid)
	return self.tasks[pid]
end

return scheduler
