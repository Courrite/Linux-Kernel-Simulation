local inode = require(script.Parent.Parent.inode)

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
	local node = inode.new("dir", ops, tbl)
	node.data  = tbl
	return node
end

local function makeExec(modTbl)
	return inode.new("file", modTbl, nil)
end

local function makeFile(content)
	local ops = {
		read = function(data, off, cnt)
			return data:sub(off + 1, off + cnt)
		end,
		write = function(data, off, buf)
			return #buf
		end,
	}
	return inode.new("file", ops, content or "")
end

local root = makeDir()
root.data.bin = makeDir()
root.data.dev = makeDir()
root.data.etc = makeDir()

for _, binMod in script.Parent.Parent.Parent.bin:GetChildren() do
	local mod = require(binMod)
	root.data.bin.data[binMod.Name] = makeExec(mod)
end

local rootfs = {
	root = root
}

function rootfs:Open(path, flags)
	local parts = string.split(path, "/")
	local node  = rootfs.root
	for _, part in parts do
		if part ~= "" then
			node = node.data[part]
			if not node then
				return nil
			end
		end
	end
	return node
end

return rootfs
