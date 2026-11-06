package main

LispProc :: #type proc(args: [dynamic]^Expr, evn: ^Env) -> (^Expr, string)

ExprSymbol :: struct {
	sym: string,
}

ExprNumber :: struct {
	num: i64,
}

ExprFloat :: struct {
	flo: f64,
}

ExprString :: struct {
	str: string,
}

ExprTrue :: struct {}

ExprNil :: struct {}

ExprCons :: struct {
	car: ^Expr,
	cdr: ^Expr,
}

ExprProc :: struct {
	pro:        LispProc,
	is_special: bool,
}

ExprLambda :: struct {
	params:  [dynamic]string,
	body:    ^Expr,
	closure: ^Env,
}

Expr :: union {
	ExprSymbol,
	ExprNumber,
	ExprFloat,
	ExprString,
	ExprTrue,
	ExprNil,
	ExprCons,
	ExprProc,
	ExprLambda,
}
