return {
	consts = {},
	prog   = {
		{ op="YIELD" },   -- never exit, just yield forever
		{ op="JMP", offset=-2 },
		
		{ op="HALT" }
	}
}
