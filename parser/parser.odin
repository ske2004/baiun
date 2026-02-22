package main

import "core:fmt"

Parser_Status :: enum {
	Ok,
	Fail,
}

Parser_Func :: #type proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status)

@(require_results)
expect_semi :: proc(parser: ^Parser, location := #caller_location) -> Parser_Status {
	if !(parser.cur_token.type == .Semi || parser.cur_token.type == .Implied_Semi) {
		parser_error(parser, "expected ; got %v", parser.cur_token.type, location = location)
		return .Fail
	}
	lex_token(parser)
	return .Ok
}

parser_error :: proc(parser: ^Parser, msg: string, args: ..any, location := #caller_location) {
	formatted := fmt.tprintf(msg, ..args)

	error(
		"\x1b[31merror at %d:%d\x1b[0m: %s\n\x1b[32m%v\x1b[0m",
		parser.cur_token.start.line + 1,
		parser.cur_token.start.column + 1,
		formatted,
		location,
	)
}

assert_next :: #force_inline proc(
	parser: ^Parser,
	type: Token_Type,
	location := #caller_location,
) {
	assert(
		parser.cur_token.type == type,
		fmt.tprintf("internal parser error: type != .%v", type),
		location,
	)
	lex_token(parser)
}

@(require_results)
expect_next :: proc(
	parser: ^Parser,
	type: Token_Type,
	location := #caller_location,
) -> Parser_Status {
	if parser.cur_token.type != type {
		parser_error(parser, "expected %v got %v", type, parser.cur_token.type, location = location)
		return .Fail
	}
	lex_token(parser)
	return .Ok
}

skip_semi :: proc(parser: ^Parser) {
	if parser.cur_token.type == .Semi || parser.cur_token.type == .Implied_Semi {
		lex_token(parser)
	}
}

@(require_results)
parser_save :: proc(parser: ^Parser) -> (point: Parser_Restore_Point) {
	point._old = parser^
	return
}

parser_restore :: proc(parser: ^Parser, point: Parser_Restore_Point) {
	parser ^= point._old
}

@(require_results)
parse_ident_or_ident_list :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	ast = ast_alloc(.Ident, parser.cur_token)
	expect_next(parser, .Ident) or_return
	
	if parser.cur_token.type == .Comma {
		assert_next(parser, .Comma)
		child := ast
		ast = ast_alloc(.Ident_List)
		ast_append(ast, child)
		
		for parser.cur_token.type == .Ident {
			child := ast_alloc(.Ident, parser.cur_token)
			assert_next(parser, .Ident)
			ast_append(ast, child)
			
			if parser.cur_token.type != .Comma {
				break
			}
			
			assert_next(parser, .Comma)
		}
	}
	return ast, .Ok
}

@(require_results)
parse_field :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	ast = ast_alloc(.Field, parser.cur_token)
	ast_append(ast, parse_ident_or_ident_list(parser) or_return)
	expect_next(parser, .Colon) or_return
	ast_append(ast, parse_expr(parser) or_return)
	
	if (parser.cur_token.type == .Eq) {
		assert_next(parser, .Eq)
		ast_append(ast, parse_expr(parser) or_return)
	}
	return
}

@(require_results)
parse_comma_delimited :: proc(parser: ^Parser, inner: Parser_Func, sentinel: Token_Type, parent: ^Ast, location := #caller_location) -> (ast: ^Ast, status: Parser_Status) {
	ast = parent
	skip_semi(parser)
	
	for {
		ast_append(ast, inner(parser) or_return)
		skip_semi(parser)
		// fmt.printf("here %v:%v %v\n", parser.src_iter.line, parser.src_iter.column, parser.cur_token.type)
		
		if parser.cur_token.type == .Comma {
			assert_next(parser, .Comma)
		} else if parser.cur_token.type == sentinel {
			break
		} else {
			expect_next(parser, sentinel, location=location) or_return
		}
	}
	
	return
}

@(require_results)
parse_fn_signature :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	expect_next(parser, .Lpar) or_return
	ast = ast_alloc(.Fn_Signature)
	args := parse_comma_delimited(parser, parse_field, .Rpar, ast_alloc(.Fn_Args)) or_return
	ast_append(ast, args)
	expect_next(parser, .Rpar) or_return
	if parser.cur_token.type == .Colon {
		assert_next(parser, .Colon)
		returns := ast_alloc(.Fn_Returns)
		ast_append(returns, parse_expr(parser) or_return)
		ast_append(ast, returns)
	}
	
	return
}

// NOTE: there's a bug that you can assign default values to fields, though maybe that should be checked in the semantic checker
@(require_results)
parse_struct :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	ast = ast_alloc(.Struct)
	assert_next(parser, .Kw_Struct)
	
	return parse_braced_semi_group(parser, ast, parse_field)
}

@(require_results)
parse_enum :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	@(require_results)
	parse_enum_item :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
		ast = ast_alloc(.Enum_Item, parser.cur_token)

		expect_next(parser, .Ident) or_return
		if parser.cur_token.type == .Eq {
			expect_next(parser, .Eq) or_return
			ast_append(ast, parse_expr(parser) or_return)
		}
		return
	}
	
	ast = ast_alloc(.Enum)
	assert_next(parser, .Kw_Enum)
	return parse_braced_semi_group(parser, ast, parse_enum_item)
}

@(require_results)
parse_interface :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	@(require_results)
	parse_interface_item :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
		// i.e. 
		// 
		// interface {
		//   mod::ident <- inherit
		//   ident      <- inherit
		//   x()        <- signature
		//   x::y()     <- will be parsed as inherit initially, but raise an error after
		// }
		ident := parse_qual_ident(parser) or_return
		if ident.type == .Qual_Ident || parser.cur_token.type != .Lpar { // inherit
			ast = ast_alloc(.Interface_Inherit_Item)
			ast_append(ast, ident)
		} else { // signature
			ast = ast_alloc(.Interface_Sig_Item)
			ast_append(ast, ident)
			ast_append(ast, parse_fn_signature(parser) or_return)	
		}
		return
	}
	
	ast = ast_alloc(.Interface)
	assert_next(parser, .Kw_Interface)
	return parse_braced_semi_group(parser, ast, parse_interface_item)
}

@(require_results)
parse_qual_ident :: proc(parser: ^Parser)-> (ast: ^Ast, status: Parser_Status) {
	ast = ast_alloc(.Ident, parser.cur_token)
	lex_token(parser)
	
	if parser.cur_token.type == .Colon_Colon {
		assert_next(parser, .Colon_Colon)
		ast.type = .Qual_Ident
		
		sub := ast_alloc(.Ident, parser.cur_token)
		expect_next(parser, .Ident) or_return
	}
	
	return
}

@(require_results)
parse_atom :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	#partial switch parser.cur_token.type {
	case .String:
		ast = ast_alloc(.String, parser.cur_token)
		lex_token(parser)
	case .Number:
		ast = ast_alloc(.Number, parser.cur_token)
		lex_token(parser)
	case .Lbrack:
		ast = ast_alloc(.Dynarray)
		lex_token(parser)
		expect_next(parser, .Rbrack) or_return
		ast_append(ast, parse_atom(parser) or_return)
	case .Lpar:
		assert_next(parser, .Lpar)
		ast = parse_expr(parser) or_return
		expect_next(parser, .Rpar) or_return
	case .Caret:
		ast = ast_alloc(.Ptr)
		lex_token(parser)
		ast_append(ast, parse_atom(parser) or_return)
	case .Kw_Struct:
		ast = parse_struct(parser) or_return
	case .Kw_Enum:
		ast = parse_enum(parser) or_return
	case .Kw_Interface:
		ast = parse_interface(parser) or_return
	case .Ident:
		ast = parse_qual_ident(parser) or_return
	}

	return
}

@(require_results)
parse_designator :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	left := parse_atom(parser) or_return
	
	loop: for {
		recv := left

		#partial switch parser.cur_token.type {
		case .Lbrack:
			assert_next(parser, .Lbrack)
			left = ast_alloc(.Index)
			ast_append(left, recv)
			ast_append(left, parse_expr(parser) or_return)
			expect_next(parser, .Rbrack) or_return
		case .Lpar:
			assert_next(parser, .Lpar)
			left = ast_alloc(.Call)
			ast_append(left, recv)
			left = parse_comma_delimited(parser, parse_expr, .Rpar, left) or_return
			expect_next(parser, .Rpar) or_return
		case .Dot:
			assert_next(parser, .Dot)
			left = ast_alloc(.Access, parser.cur_token)
			ast_append(left, recv)
			expect_next(parser, .Ident) or_return
		case .Caret:
			left = ast_alloc(.Deref)
			ast_append(left, recv)
			assert_next(parser, .Caret)
		case:	
			break loop
		}	
	}
	
	return left, .Ok
}

@(require_results)
parse_bin_generic :: #force_inline proc(
	parser: ^Parser,
	lower: Parser_Func,
	tokens: bit_set[Token_Type],
) -> (
	ast: ^Ast,
	status: Parser_Status,
) {
	ast = lower(parser) or_return

	for (parser.cur_token.type in tokens) {
		lex_token(parser)
		left := ast
		ast = ast_alloc(.Binary_Op, parser.cur_token)
		ast_append(ast, left)
		ast_append(ast, lower(parser) or_return)
	}

	return
}

parse_factor :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	// TODO
	return parse_designator(parser)
}

@(require_results)
parse_expr :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	parse_term :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
		return parse_bin_generic(parser, parse_factor, {.Mul, .Div, .Mod, .Lshift, .Rshift, .And})
	}

	parse_relation_term :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
		return parse_bin_generic(parser, parse_term, {.Plus, .Minus, .Or_Or, .Xor})
	}

	parse_relation :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
		return parse_bin_generic(
			parser,
			parse_relation_term,
			{.Eq_Eq, .Not_Eq, .Less, .Less_Eq, .More, .More_Eq},
		)
	}

	parse_logical_and :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
		return parse_bin_generic(parser, parse_relation, {.And_And})
	}

	parse_logical_or :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
		return parse_bin_generic(parser, parse_logical_and, {.Or_Or})
	}

	parse_ternary :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
		ast = parse_logical_or(parser) or_return

		for parser.cur_token.type == .Question {
			left := ast
			ast = ast_alloc(.Ternary, left.token)
			ast_append(ast, left)

			assert_next(parser, .Question)
			ast_append(ast, parse_logical_or(parser) or_return)

			expect_next(parser, .Colon) or_return
			ast_append(ast, parse_logical_or(parser) or_return)
		}

		return
	}

	return parse_ternary(parser)
}

@(require_results)
parse_braced_semi_group :: #force_inline proc(
	parser: ^Parser,
	parent: ^Ast,
	item_func: Parser_Func,
) -> (
	ast: ^Ast,
	status: Parser_Status,
) {
	ast = parent
	expect_next(parser, .Lbrace) or_return

	for parser.cur_token.type != .Rbrace {
		ast_append(ast, item_func(parser) or_return)
		if parser.cur_token.type != .Rbrace {
			expect_semi(parser) or_return
		}
	}
	expect_next(parser, .Rbrace) or_return
	
	return
}

// If it finds `(`, then it's a group or falls back to parsing the item.
//
// type (			<-- group
// type X = int	<-- item
@(require_results)
parse_stmt_group_maybe :: #force_inline proc(
	parser: ^Parser,
	item_func: Parser_Func,
) -> (
	ast: ^Ast,
	status: Parser_Status,
) {
	if parser.cur_token.type == .Lpar {
		ast = ast_alloc(.Stmt_Group)
		assert_next(parser, .Lpar)
		for parser.cur_token.type != .Rpar {
			ast_append(ast, item_func(parser) or_return)
			if parser.cur_token.type != .Rpar {
				expect_semi(parser) or_return
			}
		}
		expect_next(parser, .Rpar) or_return
	} else {
		return item_func(parser)
	}

	return
}

@(require_results)
parse_import_stmt :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	@(require_results)
	parse_import_item :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
		if parser.cur_token.type == .Ident {
			ast = ast_alloc(.Import_Named, parser.cur_token)
			assert_next(parser, .Ident)
			expect_next(parser, .Eq) or_return

			import_item := ast_alloc(.Import_Item, parser.cur_token)
			expect_next(parser, .String) or_return
			ast_append(ast, import_item)
		} else {
			ast = ast_alloc(.Import_Item, parser.cur_token)
			expect_next(parser, .String) or_return
		}
		return
	}

	ast = ast_alloc(.Import_Stmt)
	assert_next(parser, .Kw_Import)
	return ast_append(ast, parse_stmt_group_maybe(parser, parse_import_item) or_return), .Ok
}

@(require_results)
parse_var_stmt :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	ast = ast_alloc(.Var_Stmt)
	assert_next(parser, .Kw_Var)
	return ast_append(ast, parse_stmt_group_maybe(parser, parse_field) or_return), .Ok
}

@(require_results)
parse_type_stmt :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	parse_type_item :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
		ast = ast_alloc(.Type_Item, parser.cur_token)
		expect_next(parser, .Ident) or_return
		expect_next(parser, .Eq) or_return
		return ast_append(ast, parse_expr(parser) or_return), .Ok
	}

	ast = ast_alloc(.Type_Stmt)
	assert_next(parser, .Kw_Type)
	return ast_append(ast, parse_stmt_group_maybe(parser, parse_type_item) or_return), .Ok
}

@(require_results)
parse_fn_stmt :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	assert_next(parser, .Kw_Fn)

	ast = ast_alloc(.Fn_Stmt, parser.cur_token)
	expect_next(parser, .Ident) or_return
	
	ast_append(ast, parse_fn_signature(parser) or_return)
	if parser.cur_token.type == .Lbrace {
		ast_append(ast, parse_code_block(parser) or_return)
	}

	return
}

@(require_results)
parse_short_var_decl :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	ast = ast_alloc(.Short_Var_Decl, parser.cur_token)
	parse_ident_or_ident_list()
	expect_next(parser, .Ident) or_return
	
	ast_append(ast, parse_expr(parser) or_return)
	return ast, .Ok
}

@(require_results)
parse_short_var_decl_epilogue :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	restore := parser_save(parser)
	
	ast, status = parse_short_var_decl(parser)
	if status == .Ok {
		return
	}
	
	parser_restore(parser, restore)
	return nil, .Ok
}

@(require_results)
parse_for_in_header :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	parse_short_var_decl()
}

@(require_results)
parse_for_header :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	
}

@(require_results)
parse_for_stmt :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	assert_next(parser, .Kw_For)

	ast = ast_alloc(.For_Stmt, parser.cur_token)
	expect_next(parser, .Ident) or_return
	
	ast_append(ast, parse_for_signature(parser) or_return)
	if parser.cur_token.type == .Lbrace {
		ast_append(ast, parse_code_block(parser) or_return)
	}

	return
}

@(require_results)
parse_stmt :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	#partial switch parser.cur_token.type {
	case .Kw_Var: ast = parse_var_stmt(parser) or_return
	case .Kw_Type: ast = parse_type_stmt(parser) or_return
	case .Kw_Fn: ast = parse_fn_stmt(parser) or_return
	case .Kw_For: ast = parse_for_stmt(parser) or_return
	case .Lbrace: ast = parse_code_block(parser) or_return
	case: parser_error(parser, "expected statement got %v", parser.cur_token.type)
	}
	return
}

@(require_results)
parse_code_block :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	ast = ast_alloc(.Code_Block)
	ast_append(ast, parse_braced_semi_group(parser, ast, parse_stmt) or_return)
	return
}

@(require_results)
parse_toplevel :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	#partial switch parser.cur_token.type {
	case .Kw_Import: ast = parse_import_stmt(parser) or_return
	case .Kw_Var: ast = parse_var_stmt(parser) or_return
	case .Kw_Type: ast = parse_type_stmt(parser) or_return
	case .Kw_Fn: ast = parse_fn_stmt(parser) or_return
	case: parser_error(parser, "expected declaration got %v", parser.cur_token.type)
	}
	return
}

@(require_results)
parse_program :: proc(parser: ^Parser) -> (ast: ^Ast, status: Parser_Status) {
	ast = ast_alloc(.Program)

	for src_iter_going(&parser.src_iter) {
		skip_semi(parser)
		ast_append(ast, parse_toplevel(parser) or_return)
	}

	return
}

@(require_results)
parse :: proc(src: string) -> (ast: ^Ast, status: Parser_Status) {
	using parser := Parser {
		src_iter = src_iter_init(src),
	}

	lex_skip_junk(&parser)
	if !src_iter_going(&parser.src_iter) {
		error("unexpected EOF")
	}

	lex_token(&parser)

	return parse_program(&parser)
}
