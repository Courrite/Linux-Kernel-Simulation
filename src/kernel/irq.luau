local irq = {
	handlers = {}, -- irqNum -> handler function
	mask = {}, -- irqNum -> boolean
	pending = {}, -- irqNum -> true if a trigger is waiting
	priority = {}, -- lower number = higher priority
	MAX_IRQ = 32
}

function irq:Init()
	self.handlers = {}
	self.mask = {}
	self.pending = {}
	self.priority = {}
end

--- register an IRQ handler
function irq:Register(irqNum, handler, prio)
	assert(type(irqNum) == "number" and irqNum >= 0 and irqNum < self.MAX_IRQ,
		("Invalid IRQ number %s"):format(tostring(irqNum)))
	assert(type(handler) == "function", "Handler must be function")
	self.handlers[irqNum] = handler
	self.priority[irqNum] = prio or 16
end

--- unregister an IRQ handler
function irq:Unregister(irqNum)
	self.handlers[irqNum] = nil
	self.priority[irqNum] = nil
end

--- mask (disable) an IRQ line
function irq:Mask(irqNum)
	self.mask[irqNum] = true
end

--- unmask (enable) an IRQ line
function irq:Unmask(irqNum)
	self.mask[irqNum] = nil
end

--- trigger (raise) an IRQ
function irq:Trigger(irqNum, ...)
	if self.mask[irqNum] then
		return  -- dropped while masked
	end
	-- coalesce into pending; keep highest priority first when dispatching
	self.pending[irqNum] = self.pending[irqNum] or {
		irqNum = irqNum,
		args = {...}
	}
end

--- dispatch all pending IRQs in priority order
function irq:Dispatch()
	local list = {}
	for irqNum, rec in self.pending do
		table.insert(list, rec)
	end
	if #list == 0 then return end

	table.sort(list, function(a, b)
		return (self.priority[a.irqNum] or 16) < (self.priority[b.irqNum] or 16)
	end)

	self.pending = {}

	for _, rec in list do
		local handler = self.handlers[rec.irqNum]
		if handler then
			local ok, err = pcall(handler, table.unpack(rec.args))
			if not ok then
				warn(("IRQ %d handler error: %s"):format(rec.irqNum, tostring(err)))
			end
		else
			warn(("Spurious IRQ %d (no handler)"):format(rec.irqNum))
		end
	end
end

return irq
