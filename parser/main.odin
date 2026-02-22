package main

import "core:fmt"
import "core:os"
import "core:log"

error :: proc(fmt_: string, args: ..any) -> ! {
	fmt.eprintf(fmt_, ..args)
	os.exit(1)
}

main :: proc() {
	context.logger = log.create_console_logger()

	if len(os.args) != 2 {
		error("usage: %s <file.um>", os.args[0])
	}

	file := os.read_entire_file_from_path(os.args[1], context.allocator) or_else error("can't open file: %s", os.args[1])
	defer delete(file, context.allocator)

	ast, status := parse(string(file))
	if status != .Ok {
		error("parse error: %s", status)
	} else {
		ast_print(ast)
	}
}
