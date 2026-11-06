package main

new_symbol :: proc(s: string) -> ^Exp {
	exp := new(Exp)
	exp^ = ExpSymbol {
		sym = s,
	}
	return exp
}

new_nil :: proc() -> ^Exp {
	exp := new(Exp)
	exp^ = ExpNil {
		val = 0,
	}
	return exp
}

new_true :: proc() -> ^Exp {
	exp := new(Exp)
	exp^ = ExpTrue {
		val = 0,
	}
	return exp
}

new_int :: proc(num: i64) -> ^Exp {
	exp := new(Exp)
	exp^ = ExpNumber {
		num = num,
	}
	return exp
}

new_float :: proc(flo: f64) -> ^Exp {
	exp := new(Exp)
	exp^ = ExpFloat {
		flo = flo,
	}
	return exp
}

new_str :: proc(s: string) -> ^Exp {
	exp := new(Exp)
	exp^ = ExpString {
		str = s,
	}
	return exp
}

// new_list :: proc(args: [dynamic]^Exp) -> ^Exp {
// 	exp := new(Exp)
// 	exp^ = ExpList {
// 		list = args,
// 	}
// 	return exp
// }

new_cons :: proc(car: ^Exp, cdr: ^Exp) -> ^Exp {
	exp := new(Exp)
	exp^ = ExpCons {
		car = car,
		cdr = cdr,
	}
	return exp
}

new_proc :: proc(p: LispProc, is_special: bool) -> ^Exp {
	exp := new(Exp)
	exp^ = ExpProc {
		pro        = p,
		is_special = is_special,
	}
	return exp
}

new_lambda :: proc(params: [dynamic]string, body: ^Exp, closure: ^Env) -> ^Exp {
	exp := new(Exp)
	exp^ = ExpLambda {
		params  = params,
		body    = body,
		closure = closure,
	}
	return exp
}

flatten_list :: proc(list_exp: ^Exp) -> ([]^Exp, bool) {
	current := list_exp
	res: [dynamic]^Exp

	for {
		#partial switch c in current {
		case ExpCons:
			append(&res, c.car)
			current = c.cdr
		case ExpNil:
			return res[:], true // 正常なリスト
		case:
			// ドット対（不完全なリスト）の場合
			append(&res, current)
			return res[:], false
		}
	}
}
