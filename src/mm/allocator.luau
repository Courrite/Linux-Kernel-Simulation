local top = script.Parent.Parent
local constants = require(top.kernel.constants)
local allocator = {
	freeList = {} -- free list of page frames (by frame number)
}

-- number of total pages in simulated RAM
local totalPages = math.floor(constants.MEMORY.RAM_SIZE_BYTES / constants.MEMORY.PAGE_SIZE)

function allocator:Init()
	self.freeList = {}
	for i = 0, totalPages - 1 do
		table.insert(self.freeList, i)
	end
end

-- allocate n pages, return table of frame numbers or nil on failure
function allocator:Alloc(n)
	n = n or 1
	if #self.freeList < n then
		return nil, "Out of memory"
	end
	local frames = {}
	for i = 1, n do
		table.insert(frames, table.remove(self.freeList))
	end
	return frames
end

-- free previously allocated frames (table of frame numbers)
function allocator:Free(frames)
	for _, f in frames do
		table.insert(self.freeList, f)
	end
end

return allocator
