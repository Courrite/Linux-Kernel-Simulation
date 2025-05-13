local inode = require(script.Parent.Parent.Parent.fs.inode)

local random = {}

function random:Open(path, flags)
	local ops = {
		read = function(data, off, cnt)
			local out = {}
			for i = 1, cnt do
				out[i] = string.char(math.random(0, 255))
			end
			return table.concat(out)
		end,
		write = function() return 0 end,
	}
	return inode.new("char", ops, nil)
end

return random
