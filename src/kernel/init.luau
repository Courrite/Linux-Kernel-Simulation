local constants = require(script.Parent.constants)
local panic = require(script.Parent.panic)
local signals = require(script.Parent.signals)
local scheduler = require(script.Parent.scheduler)
local syscalls = require(script.Parent.syscalls)
local irq = require(script.Parent.irq)
local process = require(script.Parent.process)

local allocator = require(script.Parent.Parent.mm.allocator)
local paging = require(script.Parent.Parent.mm.paging)
local mmap = require(script.Parent.Parent.mm.mmap)

local vfs = require(script.Parent.Parent.fs.vfs)
local file = require(script.Parent.Parent.fs.file)

local pipe = require(script.Parent.Parent.ipc.pipe)
local msgq = require(script.Parent.Parent.ipc.msgqueue)
local shm = require(script.Parent.Parent.ipc.shm)

local lsm = require(script.Parent.Parent.security.lsm)

local rootfs = require(script.Parent.Parent.fs.drivers.rootfs)
local procfs = require(script.Parent.Parent.fs.drivers.procfs)
local sysfs = require(script.Parent.Parent.fs.drivers.sysfs)
local tty = require(script.Parent.Parent.drivers.char.tty)
local random = require(script.Parent.Parent.drivers.char.random)
local loopback = require(script.Parent.Parent.drivers.block.loopback)

signals:Init()
allocator:Init()
paging:Init()
mmap:Init()
scheduler:Init()
syscalls:Init()
irq:Init()
vfs:Init()

local mountFactory = {
	rootfs = function() return rootfs end,
	procfs = function() return procfs end,
	sysfs = function() return sysfs  end,
	tty = function() return tty:Open() end, -- tty itself returns a new inode
	random = function() return random:Open() end,
	loop0 = function()
		return loopback.new(
			constants.DEVICE.DISK_BLOCKS,
			constants.DEVICE.BLOCK_SIZE
		)
	end,
}

panic:SetHandler(function()
	for i = 0, irq.MAX_IRQ - 1 do
		irq:Mask(i)
	end
	
	for pid, proc in scheduler.tasks do
		warn((" PID %d: state=%s"):format(pid, proc.state or "n/a"))
		-- if you have regs/pc:
		if proc.pc then
			warn(("   PC=%d"):format(proc.pc))
		end
		-- list open fds
		local fds = vfs.fdt[pid] or {}
		local keys = {}
		for fd in fds do table.insert(keys, fd) end
		warn(("   open fds: %s"):format(table.concat(keys, ",")))
	end
	
	for pid, regions in mmap.regions do
		for _, r in regions do
			warn(("PID %d mmap @0x%X (+%d pages)"):format(pid, r.vaddr, r.npages))
		end
	end
	
	for _, p in pipe.activePipes or {} do
		warn(("Pipe buf len: %d"):format(#p._buf))
	end
	for _, p in shm.act or {} do
		warn(("Pipe buf len: %d"):format(#p._buf))
	end
	for _, p in pipe.activePipes or {} do
		warn(("Pipe buf len: %d"):format(#p._buf))
	end
end)

-- file I/O
syscalls:DefineSyscall(constants.SYSNO.VFSINIT, "vfsinit", function(pid)
	vfs:Init()
	return 0
end)

syscalls:DefineSyscall(constants.SYSNO.MOUNT, "mount", function(pid, mountPath, fsName)
	print(("[PID %d] mount(%q, %q) called"):format(pid, mountPath, fsName))

	if type(mountPath) ~= "string" or type(fsName) ~= "string" then
		warn(("[PID %d] mount failed: invalid argument types"):format(pid))
		return -constants.ERRNO.EINVAL
	end

	local factory = mountFactory[fsName]
	if not factory then
		warn(("[PID %d] mount failed: unknown filesystem name %q"):format(pid, fsName))
		return -constants.ERRNO.ENODEV
	end

	local fs = factory()
	if not fs then
		warn(("[PID %d] mount failed: filesystem factory returned nil for %q"):format(pid, fsName))
		return -constants.ERRNO.EIO
	end

	if mountPath == "/" and fsName == "rootfs" then
		print(("[PID %d] setting root filesystem to %q"):format(pid, fsName))
		vfs:SetRoot(fs)
	else
		print(("[PID %d] mounting %q at %q"):format(pid, fsName, mountPath))
		vfs:Mount(mountPath, fs)
	end

	print(("[PID %d] mount(%q, %q) succeeded"):format(pid, mountPath, fsName))
	return 0
end)


syscalls:DefineSyscall(constants.SYSNO.READ, "read", function(pid, fd, count)
	local ok, err = lsm:RunHooks("file_read", pid, fd, count)
	if not ok then return -err end
	return vfs:Read(pid, fd, count)
end)

syscalls:DefineSyscall(constants.SYSNO.WRITE, "write", function(pid, fd, buf)
	local ok, err = lsm:RunHooks("file_write", pid, fd, buf)
	if not ok then 
		return -err 
	end

	
	local result, err = vfs:Write(pid, fd, buf)
	if not result then
		return -err
	end

	return result
end)

syscalls:DefineSyscall(constants.SYSNO.OPEN, "open", function(pid, path, flags)
	-- this is the one that returns (fd, err) and populates fdt
	local fd, err = vfs:Open(pid, path, flags)
	if not fd then
		return -err
	end

	return fd
end)

syscalls:DefineSyscall(constants.SYSNO.CLOSE, "close", function(pid, fd)
	return vfs:Close(pid, fd)
end)

syscalls:DefineSyscall(constants.SYSNO.LSEEK, "lseek", function(pid, fd, offset, whence)
	local handle = vfs.fdt[pid] and vfs.fdt[pid][fd]
	if not handle then return -constants.ERRNO.EBADF end
	return file:lseek(handle, offset, whence)
end)

syscalls:DefineSyscall(constants.SYSNO.DUP, "dup", function(pid, oldfd)
	local handle = vfs.fdt[pid] and vfs.fdt[pid][oldfd]
	if not handle then return -constants.ERRNO.EBADF end
	return file:dup(handle, pid, oldfd)
end)

syscalls:DefineSyscall(constants.SYSNO.DUP2, "dup2", function(pid, oldfd, newfd)
	local handle = vfs.fdt[pid] and vfs.fdt[pid][oldfd]
	if not handle then return -constants.ERRNO.EBADF end
	return file:dup2(handle, pid, oldfd, newfd)
end)

syscalls:DefineSyscall(constants.SYSNO.GETDENTS, "getdents", function(pid, fd)
	local handle = vfs.fdt[pid] and vfs.fdt[pid][fd]
	if not handle then return -constants.ERRNO.EBADF end

	local inode = handle.inode
	if inode.type ~= "dir" then return -constants.ERRNO.ENOTDIR end

	handle.dirPos = handle.dirPos or 1
	local entries = inode.ops.list(inode.data)

	local name = entries[handle.dirPos]
	if not name then return "" end

	handle.dirPos += 1
	return name
end)

-- process control
syscalls:DefineSyscall(constants.SYSNO.FORK, "fork", function(pid)
	return scheduler:Fork(pid)
end)

syscalls:DefineSyscall(constants.SYSNO.VFORK, "vfork", function(pid)
	-- alias, wont be fully implemented
	return scheduler:Fork(pid, true)
end)

syscalls:DefineSyscall(constants.SYSNO.EXECVE, "execve", function(pid, path, argv)
	return vfs:Exec(pid, path, argv)
end)

syscalls:DefineSyscall(constants.SYSNO.EXIT, "exit", function(pid, code)
	scheduler:Exit(pid, code)
end)

syscalls:DefineSyscall(constants.SYSNO.EXIT_GROUP, "exit_group", function(pid, code)
	scheduler:ExitGroup(pid, code)
end)

syscalls:DefineSyscall(constants.SYSNO.WAIT4, "wait4", function(pid, pid_wait, statusPtr, options)
	local child, code_or_err = scheduler:Wait4(pid, pid_wait, statusPtr, options)
	if not child then
		return -code_or_err
	end
	
	return child
end)

syscalls:DefineSyscall(constants.SYSNO.KILL, "kill", function(pid, target, sig)
	return signals:Send(target, sig) and 0 or -constants.ERRNO.ESRCH
end)

-- inter process communcation
syscalls:DefineSyscall(constants.SYSNO.PIPE, "pipe", function(pid, fdsPtr)
	local r, w = pipe.new(), pipe.new()
	local fd_r = vfs:AllocFd(pid, r)
	local fd_w = vfs:AllocFd(pid, w)
	return fd_r, fd_w
end)

-- shared memory / message queues
syscalls:DefineSyscall(constants.SYSNO.SHMGET, "shmget", function(pid, key, size, shmflg)
	local seg = shm.new(key, size)
	return seg.id
end)

syscalls:DefineSyscall(constants.SYSNO.SHMAT, "shmat", function(pid, shmid, shmaddr, shmflg)
	return shm:attach(pid, shmid, shmaddr, shmflg)
end)

syscalls:DefineSyscall(constants.SYSNO.MSGGET, "msgget", function(pid, key, msgflg)
	return msgq.new(key)
end)

syscalls:DefineSyscall(constants.SYSNO.MSGSND, "msgsnd", function(pid, msqid, msgp, msgsz, msgflg)
	return msgq:send(msqid, msgp)
end)

syscalls:DefineSyscall(constants.SYSNO.MSGRCV, "msgrcv", function(pid, msqid, msgp, msgsz, msgtyp, msgflg)
	local msg, err = msgq:receive(msqid, msgtyp)
	if not msg then return -err end
	return msg
end)

-- memory management
syscalls:DefineSyscall(constants.SYSNO.MMAP, "mmap", function(pid, addr, length, prot, flags, fd, offset)
	return mmap:Mmap(pid, addr, length, prot, flags, fd, offset)
end)

syscalls:DefineSyscall(constants.SYSNO.MUNMAP, "munmap", function(pid, addr, length)
	return mmap:Munmap(pid, addr, length)
end)

syscalls:DefineSyscall(constants.SYSNO.BRK, "brk", function(pid, addr)
	return mmap:Brk(pid, addr)
end)

-- timer tick, drives the scheduler
irq:Register(0, function()
	scheduler:Schedule()
end, 0) 

-- "hardware" timer
task.spawn(function()
	while task.wait() do
		irq:Trigger(0)
	end
end)

-- launch idle and init process (pid 0 and 1)
local initProg = require(script.Parent.Parent.sbin.init)
local idleProg = require(script.Parent.Parent.sbin.idle)
local pid

pid = scheduler.nextPid
local idleProc = process.new(pid, idleProg.prog, {}, idleProg.consts)
scheduler:CreateProcessFrom(idleProc)

pid = scheduler.nextPid
local initProc = process.new(pid, initProg.prog, {}, initProg.consts)
scheduler:CreateProcessFrom(initProc)

print("Booted")

while task.wait() do
	irq:Dispatch()
	-- note: scheduler already runs schedule in IRQ 0 handler
	if panic.called then break end
end

for pid, task in scheduler.tasks do
	if pid == 1 or pid == 0 then
		continue
	end
	scheduler:Exit(pid, 255)
end

return 0
