local inode = require(script.Parent.Parent.Parent.fs.inode)

local tty = {}

function tty:Open(path, flags)
	local ops = {
		read = function()
			return ""
		end,
		write = function(data, off, buf)
			-- n/a, idk implement ur stuff here lmao
			return #buf
		end,
	}
	
	return inode.new("char", ops, nil)
end

return tty
