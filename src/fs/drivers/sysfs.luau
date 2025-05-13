local inode = require(script.Parent.Parent.inode)
local scheduler = require(script.Parent.Parent.Parent.kernel.scheduler)

local function makeDir()
	local tbl = {}
	local ops = {
		lookup = function(data, name)
			return data[name]
		end,
		list = function(data)
			local out = {}
			for k in data do
				table.insert(out, k)
			end
			return out
		end,
	}
	return inode.new("file", ops, tbl)
end

local sys = makeDir()

function sys:Open(path, flags)
	return nil
end

return sys
