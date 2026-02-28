#+feature dynamic-literals
package main

import "core:unicode"

eoln_tokens := bit_set[Token_Type]{
	.Kw_Break, .Kw_Continue, .Kw_Return,
	.Plus_Plus, .Minus_Minus, .Rpar, .Rbrack,
	.Rbrace, .Caret, .Ident, .Number, .Char, .String
}

keywords := map[string]Token_Type{
	"break"     = .Kw_Break,
	"case"      = .Kw_Case,
	"const"     = .Kw_Const,
	"continue"  = .Kw_Continue,
	"default"   = .Kw_Default,
	"else"      = .Kw_Else,
	"enum"      = .Kw_Enum,
	"for"       = .Kw_For,
	"fn"        = .Kw_Fn,
	"import"    = .Kw_Import,
	"interface" = .Kw_Interface,
	"if"        = .Kw_If,
	"in"        = .Kw_In,
	"map"       = .Kw_Map,
	"return"    = .Kw_Return,
	"struct"    = .Kw_Struct,
	"switch"    = .Kw_Switch,
	"type"      = .Kw_Type,
	"var"       = .Kw_Var,
	"weak"      = .Kw_Weak,
}

lex_skip_junk :: proc(parser: ^Parser) -> (has_junk: bool) {
	for src_iter_peek(&parser.src_iter) != '\n' && unicode.is_space(src_iter_peek(&parser.src_iter)) {
		has_junk = true
		src_iter_next(&parser.src_iter)
	}

	if src_iter_peek(&parser.src_iter) == '/' && src_iter_peek(&parser.src_iter, 1) == '/' {
		has_junk = true
		for src_iter_going(&parser.src_iter) && src_iter_peek(&parser.src_iter) != '\n' {
			src_iter_next(&parser.src_iter)
		}
	} else if src_iter_peek(&parser.src_iter) == '/' && src_iter_peek(&parser.src_iter, 1) == '*' {
		has_junk = true
		for src_iter_going(&parser.src_iter) && src_iter_peek(&parser.src_iter) != '*' && src_iter_peek(&parser.src_iter, 1) != '/' {
			src_iter_next(&parser.src_iter)
		}
	}
	

	return
}

lex_token :: proc(parser: ^Parser) -> (token: Token) {
	for {
		for lex_skip_junk(parser) {}
		
		if src_iter_peek(&parser.src_iter) == '\n' {
			if parser.cur_token.type in eoln_tokens {
				token.type = .Implied_Semi
				token.start = parser.src_iter.line_info
				src_iter_next(&parser.src_iter)
				parser.cur_token = token
				return
			} else {
				src_iter_next(&parser.src_iter)
			}
		} else {
			break
		}
	}
	
	token.start = parser.src_iter.line_info

	cur := src_iter_peek(&parser.src_iter)

	if unicode.is_alpha(cur) {
		token.type = .Ident

		for unicode.is_alpha(cur) || unicode.is_digit(cur) || cur == '_' {
			src_iter_next(&parser.src_iter)
			cur = src_iter_peek(&parser.src_iter)
		}
	} else if unicode.is_digit(cur) {
		token.type = .Number
		
		for unicode.is_digit(cur) {
			src_iter_next(&parser.src_iter)
			cur = src_iter_peek(&parser.src_iter)
		}
	} else if cur == '\"' {
		token.type = .String

		src_iter_next(&parser.src_iter)
		for src_iter_going(&parser.src_iter) && src_iter_peek(&parser.src_iter) != '\"' {
			if src_iter_peek(&parser.src_iter) == '\\' {
				src_iter_next(&parser.src_iter)
			}
			src_iter_next(&parser.src_iter)
		}

		if !src_iter_going(&parser.src_iter) {
			error("unexpected eof")
		}
		
		/* skip closing " */
		src_iter_next(&parser.src_iter)
	} else {
		// single char
		switch (cur) {
		case '.': token.type = .Dot
		case '(': token.type = .Lpar
		case ')': token.type = .Rpar
		case '[': token.type = .Lbrack
		case ']': token.type = .Rbrack
		case '{': token.type = .Lbrace
		case '}': token.type = .Rbrace
		case ',': token.type = .Comma
		case ':':
			token.type = .Colon
			if src_iter_peek(&parser.src_iter, 1) == ':' {
				src_iter_next(&parser.src_iter)
				token.type = .Colon_Colon
			} else if src_iter_peek(&parser.src_iter, 1) == '=' {
				src_iter_next(&parser.src_iter)
				token.type = .Colon_Eq
			}
		case ';': token.type = .Semi
		case '^': token.type = .Caret
		case '*': token.type = .Mul
		case '/': token.type = .Div
		case '-':
			token.type = .Minus
			if src_iter_peek(&parser.src_iter, 1) == '-' {
				src_iter_next(&parser.src_iter)
				token.type = .Minus_Minus
			}
		case '+':
			token.type = .Plus
			if src_iter_peek(&parser.src_iter, 1) == '+' {
				src_iter_next(&parser.src_iter)
				token.type = .Plus_Plus
			}
		case '%': token.type = .Mod
		case '?': token.type = .Question
		case '<':
			token.type = .Less
			if src_iter_peek(&parser.src_iter, 1) == '=' {
				src_iter_next(&parser.src_iter)
				token.type = .Less_Eq
			} else if src_iter_peek(&parser.src_iter, 1) == '<' {
				src_iter_next(&parser.src_iter)
				token.type = .Lshift
			}
		case '>':
			token.type = .More
			if src_iter_peek(&parser.src_iter, 1) == '=' {
				src_iter_next(&parser.src_iter)
				token.type = .More_Eq
			} else if src_iter_peek(&parser.src_iter, 1) == '>' {
				src_iter_next(&parser.src_iter)
				token.type = .Rshift
			}
		case '|':
			token.type = .Or
			if src_iter_peek(&parser.src_iter, 1) == '|' {
				src_iter_next(&parser.src_iter)
				token.type = .Or_Or
			}
		case '&':
			token.type = .And
			if src_iter_peek(&parser.src_iter, 1) == '&' {
				src_iter_next(&parser.src_iter)
				token.type = .And_And
			}
		case '=':
			if src_iter_peek(&parser.src_iter, 1) == '=' {
				token.type = .Eq_Eq
			}
			token.type = .Eq
		case '!':
			if src_iter_peek(&parser.src_iter, 1) == '=' {
				token.type = .Not_Eq
			}
			token.type = .Not
		case 0:   token.type = .Eof
		case:
			error("unexpected char '%c' %d:%d", cur, parser.src_iter.line+1, parser.src_iter.column+1)
		}

		src_iter_next(&parser.src_iter)
	}
	
	token.end = parser.src_iter.line_info

	token.slice = parser.src_iter.src[token.start.pos:token.end.pos]

	if token.type == .Ident && token.slice in keywords {
		token.type = keywords[token.slice]
	}

	parser.cur_token = token

	return
}
