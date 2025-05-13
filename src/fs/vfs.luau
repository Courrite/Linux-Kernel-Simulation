local constants = require(script.Parent.Parent.kernel.constants)
local inodeMod = require(script.Parent.inode)
local fileMod = require(script.Parent.file)

local scheduler = require(script.Parent.Parent.kernel.scheduler)
local process = require(script.Parent.Parent.kernel.process)

local vfs = {
	root = nil,
	mounts = {}, -- mountPoint -> fs module
	cwd = {}, -- pid -> { inode, path }
	fdt = {}, -- pid -> { fd -> file handle }
	nextFd = {}, -- pid -> next available FD
}

function vfs:Init()
	self.root = nil
	self.mounts = {}
	self.cwd = {}
	self.fdt = {}
	self.nextFd = {}
end

-- sets the root filesystem module
function vfs:SetRoot(fs)
	self.root = fs
end

-- mounts a filesystem at a specific path
function vfs:Mount(mountPath, fs)
	mountPath = mountPath:gsub("/*$", "")
	if mountPath == "" then mountPath = "/" end

	self.mounts[mountPath] = fs

	if mountPath ~= "/" then
		local parentPath, name = mountPath:match("^(.*)/([^/]+)$")
		if parentPath == "" then parentPath = "/" end

		local parentNode = self:Resolve(parentPath, 0) -- PID 0 = kernel context
		if parentNode and parentNode.ops.mkdir then
			local check = parentNode.ops.lookup and parentNode.ops.lookup(parentNode.data, name)
			if not check then
				parentNode.ops.mkdir(parentNode.data, name)
			end
		end
	end
end

-- allocate a new FD for any object (inode, pipe endpoint, etc.)
function vfs:AllocFd(pid, obj)
	self.fdt[pid]    = self.fdt[pid] or {}
	self.nextFd[pid] = self.nextFd[pid] or 3

	local fd = self.nextFd[pid]
	self.nextFd[pid] += 1

	self.fdt[pid][fd] = {
		inode = obj, -- underlying file/inode/pipe/etc.
		offset = 0, -- for files
		dirPos = 1, -- for directories
		flags = {}, -- open mode flags ("r", "w", etc.)
	}

	return fd
end

-- exec a filesystem node with an .exec() op
function vfs:Exec(pid, path, argv)
	local prog, err = self:Resolve(path, pid)
	if not prog then return nil, err end
	
	local proc = process.new(pid, prog.ops.prog, {}, prog.ops.consts)
	if not proc then
		return nil, constants.ERRNO.EAGAIN
	end

	scheduler:CreateProcessFrom(proc)

	return proc
end

-- finds filesystem and relative path for a given absolute path
function vfs:_resolveMount(absPath)
	local bestMp, bestLen, bestFs = nil, 0, nil
	for mp, fs in self.mounts do
		if absPath:sub(1, #mp) == mp and (absPath:sub(#mp+1, #mp+1) == "/" or #absPath == #mp) then
			if #mp > bestLen then
				bestMp, bestLen, bestFs = mp, #mp, fs
			end
		end
	end

	if bestFs then
		local relPath = absPath:sub(bestLen + 1)
		if relPath:sub(1, 1) == "/" then
			relPath = relPath:sub(2)
		end
		return bestFs, relPath
	end

	return self.root, absPath:sub(2)  -- remove leading "/" for rootfs
end

-- resolves a path (relative or absolute) to an inode
function vfs:Resolve(path, pid)
	local absPath
	if path:sub(1,1) == "/" then
		absPath = path
	else
		local cwdInfo = self.cwd[pid]
		if not cwdInfo then return nil, constants.ERRNO.ENOENT end
		absPath = cwdInfo.path:gsub("/*$", "") .. "/" .. path
	end

	-- find the correct fs and subpath
	local fs, sub = self:_resolveMount(absPath)
	if not fs then return nil, constants.ERRNO.ENOENT end
	-- delegate to filesystem's open/lookup
	local node = fs:Open(sub)
	if not node then return nil, constants.ERRNO.ENOENT end
	return node
end

-- opens a file, returns a new FD
function vfs:Open(pid, path, flags)
	local node, err = self:Resolve(path, pid)
	if not node then return nil, err end

	-- initialize per-pid tables
	self.fdt[pid]    = self.fdt[pid] or {}
	self.nextFd[pid] = self.nextFd[pid] or 3

	local fd = self.nextFd[pid]
	self.nextFd[pid] = fd + 1
	self.fdt[pid][fd] = fileMod.new(node)
	return fd
end

-- read from FD
function vfs:Read(pid, fd, count)
	local tbl = self.fdt[pid]
	if not tbl or not tbl[fd] then return nil, constants.ERRNO.EBADF end
	return tbl[fd]:Read(count)
end

-- write to FD
function vfs:Write(pid, fd, data)
	local tbl = self.fdt[pid]
	if not tbl or not tbl[fd] then return nil, constants.ERRNO.EBADF end
	return tbl[fd]:Write(data)
end

-- close FD
function vfs:Close(pid, fd)
	local tbl = self.fdt[pid]
	if not tbl or not tbl[fd] then return nil, constants.ERRNO.EBADF end
	tbl[fd] = nil
	return true
end

-- changes current working directory
function vfs:Chdir(pid, path)
	local node, err = self:Resolve(path, pid)
	if not node or node.type ~= "dir" then return nil, constants.ERRNO.ENOTDIR end
	self.cwd[pid] = { inode = node, path = path }
	return true
end

-- get current working directory path
function vfs:GetCwd(pid)
	return self.cwd[pid] and self.cwd[pid].path or "/"
end

return vfs
