package main

import "core:fmt"

ast_print :: proc (ast: ^Ast, depth: int = 0) {
	if ast == nil {
		return
	}

	for i in 0..<depth {
		fmt.printf(" ")
	}
	
	if token, ok := ast.token.?; ok {
		fmt.printf("%v %s (%s) %d:%d\n", ast.type, token.type, token.slice, token.start.line, token.start.column)
	} else {
		fmt.printf("%v\n", ast.type)
	}

	ast_print(ast.child, depth+2)
	ast_print(ast.sibling, depth)
}
