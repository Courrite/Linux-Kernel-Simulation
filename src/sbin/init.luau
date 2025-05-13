local constants = require(game.ReplicatedStorage.kernel.constants)

local consts = {
	[1] = "/", -- root mount point
	[2] = "/proc",
	[3] = "/sys",
	[4] = "/dev/tty",
	[5] = "/dev/random",
	[6] = "/bin/sh",
	[7] = "rootfs",
	[8] = "procfs",
	[9] = "sysfs",
	[10] = "tty",
	[11] = "random",
}

local prog = {
	-- vfs initialization
	{ op = "LOADIM",  dst = 1, imm = constants.SYSNO.VFSINIT },
	{ op = "SYSCALL", numReg = 1, argCount = 0 },

	-- mount "/"
	{ op = "LOADIM",  dst = 1, imm = constants.SYSNO.MOUNT },
	{ op = "LOADSTR", dstAddrReg = 2, constId = 1 }, -- mount path
	{ op = "LOADSTR", dstAddrReg = 3, constId = 7 }, -- fs name: rootfs
	{ op = "SYSCALL", numReg = 1, arg1 = 2, arg2 = 3, argCount = 2 },

	-- mount "/proc"
	{ op = "LOADIM",  dst = 1, imm = constants.SYSNO.MOUNT },
	{ op = "LOADSTR", dstAddrReg = 2, constId = 2 }, -- mount path
	{ op = "LOADSTR", dstAddrReg = 3, constId = 8 }, -- fs name: procfs
	{ op = "SYSCALL", numReg = 1, arg1 = 2, arg2 = 3, argCount = 2 },

	-- mount "/sys"
	{ op = "LOADIM",  dst = 1, imm = constants.SYSNO.MOUNT },
	{ op = "LOADSTR", dstAddrReg = 2, constId = 3 }, -- mount path
	{ op = "LOADSTR", dstAddrReg = 3, constId = 9 }, -- fs name: sysfs
	{ op = "SYSCALL", numReg = 1, arg1 = 2, arg2 = 3, argCount = 2 },

	-- mount "/dev/tty"
	{ op = "LOADIM",  dst = 1, imm = constants.SYSNO.MOUNT },
	{ op = "LOADSTR", dstAddrReg = 2, constId = 4 }, -- mount path
	{ op = "LOADSTR", dstAddrReg = 3, constId = 10 }, -- fs name: tty
	{ op = "SYSCALL", numReg = 1, arg1 = 2, arg2 = 3, argCount = 2 },

	-- mount "/dev/random"
	{ op = "LOADIM",  dst = 1, imm = constants.SYSNO.MOUNT },
	{ op = "LOADSTR", dstAddrReg = 2, constId = 5 }, -- mount path
	{ op = "LOADSTR", dstAddrReg = 3, constId = 11 }, -- fs name: random
	{ op = "SYSCALL", numReg = 1, arg1 = 2, arg2 = 3, argCount = 2 },

	-- yield indefinitely
	{ op = "YIELD" },
	{ op = "JMP",     offset = -1 }, -- loop back to yield indefinitely
	
	-- should not return here
	{ op = "HALT" },
}

return { consts = consts, prog = prog }
