package main

import "core:fmt"
import "core:strings"

LispProc :: #type proc(args: [dynamic]^Exp) -> (^Exp, string)

ExpSymbol :: struct {
	sym: string,
}

ExpNumber :: struct {
	num: i64,
}

ExpFloat :: struct {
	flo: f64,
}

ExpString :: struct {
	str: string,
}

ExpTrue :: struct {
	val: int,
}

ExpNil :: struct {
	val: int,
}

ExpList :: struct {
	list: [dynamic]^Exp,
}

ExpProc :: struct {
	pro: LispProc,
}

ExpLambda :: struct {
	params:  [dynamic]string,
	body:    ^Exp,
	closure: ^Env,
}

Exp :: union {
	ExpSymbol,
	ExpNumber,
	ExpFloat,
	ExpString,
	ExpTrue,
	ExpNil,
	ExpList,
	ExpProc,
	ExpLambda,
}

List :: [dynamic]string

exp_to_string :: proc(exp: ^Exp) -> string {
	switch e in exp {
	case ExpSymbol:
		return e.sym
	case ExpNumber:
		return fmt.tprintf("%d", e.num)
	case ExpFloat:
		return fmt.tprintf("%g", e.flo)
	case ExpString:
		return fmt.tprintf("\"%s\"", e.str)
	case ExpList:
		sb := strings.builder_make()
		strings.write_string(&sb, "(")
		for item, i in e.list {
			if i > 0 {
				strings.write_string(&sb, ", ")
			}
			item_str := exp_to_string(item)
			strings.write_string(&sb, item_str)
		}
		strings.write_string(&sb, ")")
		return strings.to_string(sb)
	case ExpTrue:
		return "T"
	case ExpNil:
		return "NIL"
	case ExpProc:
		return "<proc>"
	case ExpLambda:
		return "<lambda>"
	}
	unreachable()
}
