package main

Line_Info :: struct #all_or_none {
	pos, line, column: int
}

Src_Iter :: struct {
	src: string,
	using line_info: Line_Info
}

Token_Type :: enum {
	Invalid,
	Ident,
	String,
	Char,
	Number,
	
	Lpar,
	Rpar,
	Lbrace,
	Rbrace,
	Lbrack,
	Rbrack,
	
	And,
	And_And,
	Caret,
	Colon,
	Colon_Colon,
	Colon_Eq, // walrus
	Comma,
	Div,
	Dot,
	Eq,
	Eq_Eq,
	Less,
	Less_Eq,
	Lshift,
	Minus,
	Minus_Minus,
	Mod,
	More,
	More_Eq,
	Mul,
	Not,
	Not_Eq,
	Or,
	Or_Or,
	Plus,
	Plus_Plus,
	Question,
	Rshift,
	Xor, // aka Not
	
	Kw_Break,
	Kw_Case,
	Kw_Const,
	Kw_Continue,
	Kw_Default,
	Kw_Else,
	Kw_Enum,
	Kw_For,
	Kw_Fn,
	Kw_Import,
	Kw_Interface,
	Kw_If,
	Kw_In,
	Kw_Map,
	Kw_Return,
	Kw_Struct,
	Kw_Switch,
	Kw_Type,
	Kw_Var,
	Kw_Weak,
	
	Implied_Semi,
	Semi,
	
	Eof,
}

Token :: struct {
	slice: string,
	type: Token_Type,
	using start: Line_Info,
	end: Line_Info,
}

Parser :: struct {
	src_iter: Src_Iter,
	cur_token: Token
}

Parser_Restore_Point :: struct {
	_old: Parser
}
