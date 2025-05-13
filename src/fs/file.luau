local constants = require(script.Parent.Parent.kernel.constants)

local file = {}
file.__index = file

-- wraps an inode, tracks a per‐handle offset
function file.new(inode)
	return setmetatable({
		inode  = inode,
		offset = 0,
	}, file)
end

-- read up to `count` bytes from the current offset
function file:Read(count)
	local readFn = self.inode.ops.read
	if not readFn then
		return nil, constants.ERRNO.EBADF
	end
	local data = readFn(self.inode.data, self.offset, count) or ""
	self.offset += #data
	return data
end

-- write `buf` at the current offset
function file:Write(buf)
	local writeFn = self.inode.ops.write
	if not writeFn then
		return nil, constants.ERRNO.EBADF
	end

	if not buf then
		return nil, constants.ERRNO.EINVAL
	end
	local written = writeFn(self.inode.data, self.offset, buf) or 0
	self.offset += written

	return written
end


-- seek on a file descriptor
function file:lseek(handle, offset, whence)
	local inode = handle.inode

	if inode.type == "dir" then
		local entries = inode.ops.list(inode.data)
		local newPos = handle.dirPos or 1

		if     whence == constants.WHENCE.SEEK_SET then
			newPos = offset + 1
		elseif whence == constants.WHENCE.SEEK_CUR then
			newPos = newPos + offset
		elseif whence == constants.WHENCE.SEEK_END then
			newPos = #entries + offset + 1
		else
			return -constants.ERRNO.EINVAL
		end

		newPos = math.max(1, math.min(newPos, #entries + 1))
		handle.dirPos = newPos
		return newPos - 1

	else
		local newOffset
		if     whence == constants.WHENCE.SEEK_SET then
			newOffset = offset
		elseif whence == constants.WHENCE.SEEK_CUR then
			newOffset = handle.offset + offset
		elseif whence == constants.WHENCE.SEEK_END then
			local size = #inode.data
			newOffset = size + offset
		else
			return -constants.ERRNO.EINVAL
		end

		if newOffset < 0 then return -constants.ERRNO.EINVAL end
		handle.offset = newOffset
		return newOffset
	end
end


function file:dup(handle, pid, oldfd)
	local newfd = self.nextFd[pid] or 3
	self.nextFd[pid] = newfd + 1

	self.fdt[pid][newfd] = {
		inode = handle.inode,
		offset = handle.offset,
		dirPos = handle.dirPos,
		flags = handle.flags,
	}
	return newfd
end

function file:Dup2(handle, pid, oldfd, newfd)
	-- overwrite if it already exists
	self.fdt[pid][newfd] = {
		inode = handle.inode,
		offset = handle.offset,
		dirPos = handle.dirPos,
		flags = handle.flags,
	}

	self.nextFd[pid] = math.max(self.nextFd[pid] or 3, newfd + 1)
	return newfd
end

return file
