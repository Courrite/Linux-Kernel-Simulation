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

local proc = makeDir()

function proc:Open(path, flags)
	if path == "" then
		inode.new("dir", proc.ops, scheduler.tasks)
	end
	local pid = tonumber(path)
	if not scheduler.tasks[pid] then
		return nil
	end
	return inode.new("file", {
		read = function(_, off, cnt)
			return tostring(pid) .. "\n"
		end,
	}, "")
end

return proc
