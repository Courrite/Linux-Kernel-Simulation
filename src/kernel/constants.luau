local constants = {}

-- memory management
constants.MEMORY = {
	PAGE_SIZE = 4096,
	RAM_SIZE_BYTES = 64 * 1024,
	MAP_SHARED = 0x01,
	MAP_PRIVATE = 0x02,
	PROT_READ = 0x1,
	PROT_WRITE = 0x2,
	PROT_EXEC = 0x4,
	USER_BASE = 0x00000000,
	KERNEL_BASE = 0xC0000000
}

-- disk and block devices
constants.DEVICE = {
	DISK_BLOCKS = 1024,
	BLOCK_SIZE = 4096,
	DEV_TTY = 1,
	DEV_RANDOM = 2,
	DEV_LOOPBACK = 3,
	MAJOR_CHAR = 1,
	MAJOR_BLOCK = 2
}

-- file descriptors
constants.FD = {
	STDIN = 0,
	STDOUT = 1,
	STDERR = 2
}

-- system call numbers (x86-64 ABI)
constants.SYSNO = {
	READ = 0,
	WRITE = 1,
	OPEN = 2,
	CLOSE = 3,
	PIPE = 22,
	FORK = 57,
	VFORK = 58,
	EXECVE = 59,
	EXIT = 60,
	EXIT_GROUP = 231,
	WAIT4 = 61,
	KILL = 62,
	MMAP = 9,
	MUNMAP = 11,
	BRK = 12,
	LSEEK = 8,
	DUP = 32,
	DUP2 = 33,
	MSGGET = 68,
	MSGSND = 69,
	MSGRCV = 70,
	MSGCTL = 71,
	SHMGET = 74,
	SHMAT = 75,
	SHMDT = 76,
	SHMCTL = 77,
	GETDENTS = 78,
	PSNEXT = 100,
	MOUNT = 201,
	VFSINIT = 202
}

-- error codes
constants.ERRNO = {
	EPERM = 1,
	ENOENT = 2,
	ESRCH = 3,
	EINTR = 4,
	EIO = 5,
	ENXIO = 6,
	E2BIG = 7,
	ENOEXEC = 8,
	EBADF = 9,
	ECHILD = 10,
	EAGAIN = 11,
	ENOMEM = 12,
	EACCES = 13,
	EFAULT = 14,
	EINVAL = 22,
	ENOSYS = 38,
	ENOMSG = 42
}

-- signals
constants.SIGNALS = {
	SIGHUP = 1,
	SIGINT = 2,
	SIGQUIT = 3,
	SIGILL = 4,
	SIGABRT = 6,
	SIGFPE = 8,
	SIGKILL = 9,
	SIGUSR1 = 10,
	SIGSEGV = 11,
	SIGUSR2 = 12,
	SIGPIPE = 13,
	SIGALRM = 14,
	SIGTERM = 15,
	SIGCHLD = 17,
	SIGCONT = 18,
	SIGSTOP = 19,
	SIGTSTP = 20,
	SIGTTIN = 21,
	SIGTTOU = 22
}

return constants
