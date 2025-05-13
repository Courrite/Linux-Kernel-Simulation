local inode = require(script.Parent.Parent.Parent.fs.inode)

local loopback = {}
loopback.__index = loopback

function loopback.new(numBlocks, blockSize)
	assert(type(numBlocks) == "number" and type(blockSize) == "number",
		"loopback.new requires (numBlocks, blockSize)")
	-- flat storage buffer
	local storage = string.rep("\0", numBlocks * blockSize)
	return setmetatable({
		storage   = storage,
		blockSize = blockSize,
	}, loopback)
end

function loopback:Open(path, flags)
	local ops = {
		read = function(_, offset, count)
			return self.storage:sub(offset + 1, offset + count)
		end,
		write = function(_, offset, buf)
			-- splice the buffer into storage
			local before = self.storage:sub(1, offset)
			local after  = self.storage:sub(offset + #buf + 1)
			self.storage = before .. buf .. after
			return #buf
		end,
	}

	local node = inode.new("blk", ops, nil)
	return node
end

return loopback
