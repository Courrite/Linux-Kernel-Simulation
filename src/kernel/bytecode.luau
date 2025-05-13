local constants = require(script.Parent.constants)
local syscalls = require(script.Parent.syscalls)

local BytecodeInstr = {}

local function findAvailableHeapAddress(proc)
	local addr = 1
	while proc.heap[addr] do
		addr = addr + 1
	end
	return addr
end

local function resolveHeapValue(proc, value)
	if type(value) == "number" then
		return proc.heap[value] or value
	else
		return value
	end
end

BytecodeInstr["LOADIM"] = function(proc, instr)
	proc.regs[instr.dst] = instr.imm
end

BytecodeInstr["LOADSTR"] = function(proc, instr)
	local constId = instr.constId
	local s = proc.consts[constId]
	local addr = findAvailableHeapAddress(proc)
	proc.heap[addr] = s
	proc.regs[instr.dstAddrReg] = addr
end

BytecodeInstr["MOV"] = function(proc, instr)
	proc.regs[instr.dst] = proc.regs[instr.src]
end

BytecodeInstr["ADD"] = function(proc, instr)
	proc.regs[instr.dst] = proc.regs[instr.src1] + proc.regs[instr.src2]
end

BytecodeInstr["SUB"] = function(proc, instr)
	proc.regs[instr.dst] = proc.regs[instr.src1] - proc.regs[instr.src2]
end

BytecodeInstr["MUL"] = function(proc, instr)
	proc.regs[instr.dst] = proc.regs[instr.src1] * proc.regs[instr.src2]
end

BytecodeInstr["DIV"] = function(proc, instr)
	proc.regs[instr.dst] = math.floor(proc.regs[instr.src1] / proc.regs[instr.src2])
end

BytecodeInstr["AND"] = function(proc, instr)
	proc.regs[instr.dst] = bit32.band(proc.regs[instr.src1], proc.regs[instr.src2])
end

BytecodeInstr["OR"] = function(proc, instr)
	proc.regs[instr.dst] = bit32.bor(proc.regs[instr.src1], proc.regs[instr.src2])
end

BytecodeInstr["XOR"] = function(proc, instr)
	proc.regs[instr.dst] = bit32.bxor(proc.regs[instr.src1], proc.regs[instr.src2])
end

BytecodeInstr["NOT"] = function(proc, instr)
	proc.regs[instr.dst] = bit32.bnot(proc.regs[instr.src])
end

BytecodeInstr["CMP"] = function(proc, instr)
	local r1, r2 = proc.regs[instr.src1] or 0, proc.regs[instr.src2] or 0
	proc.cmp = (r1 < r2 and -1) or (r1 > r2 and 1) or 0
end

BytecodeInstr["JEQ"] = function(proc, instr)
	if proc.cmp == 0 then
		proc.pc = proc.pc + instr.offset
		return true
	end
end

BytecodeInstr["JNE"] = function(proc, instr)
	if proc.cmp ~= 0 then
		proc.pc = proc.pc + instr.offset
		return true
	end
end

BytecodeInstr["JLT"] = function(proc, instr)
	if proc.cmp < 0 then
		proc.pc = proc.pc + instr.offset
		return true
	end
end

BytecodeInstr["JGT"] = function(proc, instr)
	if proc.cmp > 0 then
		proc.pc = proc.pc + instr.offset
		return true
	end
end

BytecodeInstr["JLE"] = function(proc, instr)
	if proc.cmp <= 0 then
		proc.pc = proc.pc + instr.offset
		return true
	end
end

BytecodeInstr["JGE"] = function(proc, instr)
	if proc.cmp >= 0 then
		proc.pc = proc.pc + instr.offset
		return true
	end
end

BytecodeInstr["JMP"] = function(proc, instr)
	proc.pc = proc.pc + instr.offset
	return true
end

BytecodeInstr["JMP_IFZERO"] = function(proc, instr)
	if proc.regs[instr.reg] == 0 then
		proc.pc = proc.pc + instr.offset
	else
		proc.pc = proc.pc + 1
	end
end

BytecodeInstr["LOAD"] = function(proc, instr)
	local addr = instr.addr or proc.regs[instr.addrReg]
	proc.regs[instr.dst] = proc.heap[addr] or 0
end

BytecodeInstr["STORE"] = function(proc, instr)
	local addr = instr.addr or proc.regs[instr.addrReg]
	proc.heap[addr] = proc.regs[instr.src]
end

BytecodeInstr["PUSH"] = function(proc, instr)
	proc.sp = proc.sp + 1
	proc.stack[proc.sp] = proc.regs[instr.src]
end

BytecodeInstr["POP"] = function(proc, instr)
	proc.regs[instr.dst] = proc.stack[proc.sp]
	proc.stack[proc.sp] = nil
	proc.sp = proc.sp - 1
end

BytecodeInstr["CALL"] = function(proc, instr)
	proc.sp = proc.sp + 1
	proc.stack[proc.sp] = proc.pc + 1
	proc.pc = instr.target
	return true
end

BytecodeInstr["RET"] = function(proc, instr)
	proc.pc = proc.stack[proc.sp]
	proc.stack[proc.sp] = nil
	proc.sp = proc.sp - 1
	return true
end

BytecodeInstr["DEBUG"] = function(proc, str)
	print(str, proc.regs)
end -- (not actually implemented in linux kernel, this just makes the simulated programs easier to work with)

BytecodeInstr["SYSCALL"] = function(proc, instr)
	local num = proc.regs[instr.numReg]
	local args = {}

	for i = 1, instr.argCount do
		local val = proc.regs[instr["arg" .. i]]
		table.insert(args, resolveHeapValue(proc, val))
	end

	proc.regs[1] = syscalls:Dispatch(proc.pid, num, table.unpack(args))
end

BytecodeInstr["READDIR"] = function(proc, instr)
	local fd = proc.regs[instr.fdReg]
	local name = syscalls:Dispatch(proc.pid, constants.SYSNO.GETDENTS, fd)
	if name == "" then
		proc.regs[instr.dst] = 0
	else
		local addr = findAvailableHeapAddress(proc)
		proc.heap[addr] = name
		proc.regs[instr.dst] = addr
	end
end

BytecodeInstr["HALT"] = function(proc, instr)
	proc.state = "halted"
	return false
end

BytecodeInstr["YIELD"] = function(proc, instr)
	return true
end

return BytecodeInstr
