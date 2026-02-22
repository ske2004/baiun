package main

Ast_Type :: enum {
	Program,
	
	Binary_Op,
	Deref,
	Index,
	Access,
	Call,
	Ident,
	Ident_List,
	Qual_Ident,
	Number,
	String,
	Ternary,
	
	Stmt_Group,
	
	Const_Stmt,
	Fn_Stmt,
	Import_Stmt,
	Type_Stmt,
	Var_Stmt,
	For_Stmt,
	If_Stmt,
	Short_Var_Decl,
	Code_Block,
	
	Const_Item,
	Import_Item,
	Import_Named,
	Type_Item,
	Var_Item,
	Enum_Item,
	Interface_Inherit_Item,
	Interface_Sig_Item,

	Compound_Lit,
	Compound_Or_Fn_Lit,
	Designated_Lit,
	Fn_Lit,

	Fn_Signature,
	Fn_Args,
	Fn_Returns,
	Fn_Captures,
	
	Dynarray,
	Field,
	Ptr,
	Struct,
	Enum,
	Interface,
}

Ast :: struct {
	type: Ast_Type,
	token: Maybe(Token),
	child, sibling: ^Ast
}

ast_alloc :: proc(type: Ast_Type, token: Maybe(Token) = nil) -> ^Ast {
	return new_clone(Ast{type = type, token = token}, context.temp_allocator) or_else error("Allocation error")
}

// Returns: parent
ast_append :: proc(parent: ^Ast, child: ^Ast) -> ^Ast {
	if parent.child == nil {
		parent.child = child
	} else {
		sibling := parent.child
		for sibling.sibling != nil {
			sibling = sibling.sibling
		}

		sibling.sibling = child
	}
	
	return parent
}
