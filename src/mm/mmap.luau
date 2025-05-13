local top = script.Parent.Parent
local constants = require(top.kernel.constants)
local allocator = require(script.Parent.allocator)
local paging = require(script.Parent.paging)

local mmap = {
	regions   = {}, -- pid -> list of { vaddr, npages, frames, type }
	nextBase = {},
	brkPoints = {}
}

local DEFAULT_MAP_BASE = constants.MEMORY.USER_BASE + 0x00100000
local DEFAULT_BRK_BASE = constants.MEMORY.USER_BASE + 0x01000000

function mmap:Init()
	self.regions = {}
	self.nextBase = {}
	self.brkPoints = {}
end

function mmap:Mmap(pid, addrHint, length, prot, flags)
	prot = prot or bit32.bor(constants.MEMORY.PROT_READ, constants.MEMORY.PROT_WRITE)

	local npages = math.ceil(length / constants.MEMORY.PAGE_SIZE)
	local frames, err = allocator:Alloc(npages)
	if not frames then return nil, err end

	if not self.nextBase[pid] then
		self.nextBase[pid] = DEFAULT_MAP_BASE
	end
	local vaddrBase = self.nextBase[pid]
	self.nextBase[pid] = vaddrBase + npages * constants.MEMORY.PAGE_SIZE

	for i, f in frames do
		paging:Map(pid,
			vaddrBase + (i - 1) * constants.MEMORY.PAGE_SIZE,
			f,
			prot
		)
	end

	self.regions[pid] = self.regions[pid] or {}
	table.insert(self.regions[pid], {
		vaddr  = vaddrBase,
		npages = npages,
		frames = frames,
		type   = "mmap",
	})

	return vaddrBase
end

function mmap:Brk(pid, addr)
	if not self.brkPoints[pid] then
		self.brkPoints[pid] = DEFAULT_BRK_BASE
	end
	local cur = self.brkPoints[pid]
	if addr == 0 then return cur end
	if addr < cur then return cur end

	local needed = addr - cur
	local npages = math.ceil(needed / constants.MEMORY.PAGE_SIZE)
	local frames, err = allocator:Alloc(npages)
	if not frames then return nil, err end

	local prot = bit32.bor(constants.MEMORY.PROT_READ, constants.MEMORY.PROT_WRITE)
	for i, f in frames do
		paging:Map(pid,
			cur + (i - 1) * constants.MEMORY.PAGE_SIZE,
			f, prot
		)
	end

	self.regions[pid] = self.regions[pid] or {}
	table.insert(self.regions[pid], {
		vaddr  = cur,
		npages = npages,
		frames = frames,
		type   = "brk",
	})

	self.brkPoints[pid] = cur + npages * constants.MEMORY.PAGE_SIZE
	return self.brkPoints[pid]
end

function mmap:Munmap(pid, addr, length)
	local regs = self.regions[pid] or {}
	for i, r in regs do
		if r.vaddr == addr and (not length or r.npages * constants.MEMORY.PAGE_SIZE == length) then
			for j = 0, r.npages - 1 do
				paging:Unmap(pid, addr + j * constants.MEMORY.PAGE_SIZE)
			end
			allocator:Free(r.frames)
			table.remove(regs, i)
			return true
		end
	end
	return false, "Mapping not found"
end

return mmap
