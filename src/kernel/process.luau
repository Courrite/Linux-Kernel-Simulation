local constants = require(script.Parent.constants)
local syscalls = require(script.Parent.syscalls)
local bytecode = require(script.Parent.bytecode)

local Process = {}
Process.__index = Process

local function deepcopy(orig, seen)
	seen = seen or {}
	if type(orig) ~= "table" then return orig end
	if seen[orig] then return seen[orig] end
	local copy = {}
	seen[orig] = copy
	for k,v in orig do
		copy[deepcopy(k,seen)] = deepcopy(v,seen)
	end
	setmetatable(copy, getmetatable(orig))
	return copy
end

function Process.new(pid, prog, argv, consts)
	local regs = {}
	for i = 1,8 do regs[i] = 0 end -- GPRs R1–R8
	local self = setmetatable({
		pid    = pid,
		prog   = prog,
		pc     = 1,
		regs   = regs,
		heap   = {}, -- addr -> value
		stack  = {}, -- call stack
		sp     = 0, -- stack pointer (index into stack[])
		cmp    = 0, -- result of last CMP: -1/0/1
		argv   = argv or {},
		consts = consts or {},
		state  = "ready",
	}, Process)
	
	return self
end

function Process:clone(newPid)
	local copy = deepcopy(self)
	copy.pid = newPid
	return setmetatable(copy, Process)
end

function Process:resume()
	local instr = self.prog[self.pc]
	if not instr then return false end

	local handler = bytecode[instr.op]
	if not handler then
		error(("Unknown op %q at PC=%d"):format(instr.op, self.pc))
	end

	local skipIncrement = handler(self, instr)
	if skipIncrement then return self:inRange() end

	self.pc += 1
	return self:inRange()
end

function Process:inRange()
	return self.pc >= 1 and self.pc <= #self.prog
end

return Process
