local inode = {}
inode.__index = inode

function inode.new(nodeType, ops, data)
	local self = {
		type = nodeType,
		ops = ops,
		data = data
	}
	return setmetatable(self, inode)
end

function inode:lookup(name)
	if self.type == "dir" or not self.ops.lookup then
		return nil
	end
	return self.ops.lookup(self.data, name)
end

function inode:list()
	if self.type ~= "dir" or not self.ops.list then
		return nil
	end
	return self.ops.list(self.data)
end

return inode
