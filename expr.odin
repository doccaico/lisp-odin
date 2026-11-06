package main

import "core:fmt"
import "core:strings"

LispProc :: #type proc(args: [dynamic]^Exp, evn: ^Env) -> (^Exp, string)

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

ExpCons :: struct {
	car: ^Exp,
	cdr: ^Exp,
}

ExpProc :: struct {
	pro:        LispProc,
	is_special: bool,
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
	ExpCons,
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
	case ExpCons:
		sb: strings.Builder
		strings.builder_init(&sb)
		strings.write_string(&sb, "(")

		current := exp
		main_loop: for {
			c := current.(ExpCons) // 現在のConsセル

			strings.write_string(&sb, exp_to_string(c.car))

			#partial switch next in c.cdr {
			case ExpNil:
				break main_loop
			case ExpCons:
				strings.write_string(&sb, " ")
				current = c.cdr
			case:
				strings.write_string(&sb, " . ")
				strings.write_string(&sb, exp_to_string(c.cdr))
				break main_loop
			}
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

	unimplemented("Reached the end of exp_to_string()")
}
