return {
	consts = {},
	prog   = {
		{ op="YIELD" },   -- never exit, just yield forever
		{ op="JMP", offset = -1 },
		
		{ op="HALT" }
	}
}
