local constants = require(script.Parent.Parent.kernel.constants)
local paging = {
	pageTables = {} -- { [vpn] = pfn }
}

function paging:Init()
	self.pageTables = {}
end

-- map virtual address to physical frame for a process
function paging:Map(pid, vaddr, frame)
	local vpn = math.floor(vaddr / constants.memory.PAGE_SIZE)
	self.pageTables[pid] = self.pageTables[pid] or {}
	self.pageTables[pid][vpn] = frame
end

-- unmap a virtual address
function paging:Unmap(pid, vaddr)
	local vpn = math.floor(vaddr / constants.memory.PAGE_SIZE)
	if self.pageTables[pid] then
		self.pageTables[pid][vpn] = nil
	end
end

-- translate vaddr to physical address (returns physAddr or nil)
function paging:Translate(pid, vaddr)
	local vpn = math.floor(vaddr / constants.memory.PAGE_SIZE)
	local offset = vaddr % constants.memory.PAGE_SIZE
	local pfn = self.pageTables[pid] and self.pageTables[pid][vpn]
	if not pfn then return nil end
	return pfn * constants.memory.PAGE_SIZE + offset
end

return paging
