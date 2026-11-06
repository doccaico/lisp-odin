package main

import "core:fmt"
import "core:strings"

new_symbol :: proc(s: string) -> ^Expr {
	exp := new(Expr)
	exp^ = ExprSymbol {
		sym = s,
	}
	return exp
}

new_nil :: proc() -> ^Expr {
	exp := new(Expr)
	exp^ = ExprNil{}
	return exp
}

new_true :: proc() -> ^Expr {
	exp := new(Expr)
	exp^ = ExprTrue{}
	return exp
}

new_int :: proc(num: i64) -> ^Expr {
	exp := new(Expr)
	exp^ = ExprNumber {
		num = num,
	}
	return exp
}

new_float :: proc(flo: f64) -> ^Expr {
	exp := new(Expr)
	exp^ = ExprFloat {
		flo = flo,
	}
	return exp
}

new_str :: proc(s: string) -> ^Expr {
	exp := new(Expr)
	exp^ = ExprString {
		str = s,
	}
	return exp
}

new_cons :: proc(car: ^Expr, cdr: ^Expr) -> ^Expr {
	exp := new(Expr)
	exp^ = ExprCons {
		car = car,
		cdr = cdr,
	}
	return exp
}

new_proc :: proc(p: LispProc, is_special: bool) -> ^Expr {
	exp := new(Expr)
	exp^ = ExprProc {
		pro        = p,
		is_special = is_special,
	}
	return exp
}

new_lambda :: proc(params: [dynamic]string, body: ^Expr, closure: ^Env) -> ^Expr {
	exp := new(Expr)
	exp^ = ExprLambda {
		params  = params,
		body    = body,
		closure = closure,
	}
	return exp
}

flatten_list :: proc(list_exp: ^Expr) -> ([]^Expr, bool) {
	current := list_exp
	res: [dynamic]^Expr

	for {
		#partial switch c in current {
		case ExprCons:
			append(&res, c.car)
			current = c.cdr
		case ExprNil:
			return res[:], true // 正常なリスト
		case:
			// ドット対（不完全なリスト）の場合
			append(&res, current)
			return res[:], false
		}
	}
}

to_string :: proc(expr: ^Expr) -> string {
	#partial switch e in expr {
	case ExprSymbol:
		return e.sym
	case ExprNumber:
		return fmt.tprintf("%d", e.num)
	case ExprFloat:
		return fmt.tprintf("%f", e.flo)
	case ExprString:
		return fmt.tprintf("\"%s\"", e.str)
	case ExprCons:
		sb: strings.Builder
		strings.builder_init(&sb)
		strings.write_string(&sb, "(")

		current := expr
		main_loop: for {
			c := current.(ExprCons)

			strings.write_string(&sb, to_string(c.car))

			#partial switch next in c.cdr {
			case ExprNil:
				break main_loop
			case ExprCons:
				strings.write_string(&sb, " ")
				current = c.cdr
			case:
				strings.write_string(&sb, " . ")
				strings.write_string(&sb, to_string(c.cdr))
				break main_loop
			}
		}
		strings.write_string(&sb, ")")
		return strings.to_string(sb)
	case ExprTrue:
		return "T"
	case ExprNil:
		return "NIL"
	case ExprProc:
		return "<PROC>"
	case ExprLambda:
		return "<LAMBDA>"
	}

	return "reached the end of to_string()"
}
