package main

import "core:fmt"
import "core:os"

print_and_exit :: proc(format: string, args: ..any) {
	fmt.eprintfln(format, ..args)
	os.exit(1)
}

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

new_list :: proc(args: [dynamic]^Exp) -> ^Exp {
	exp := new(Exp)
	exp^ = ExpList {
		list = args,
	}
	return exp
}

new_cons :: proc(car: ^Exp, cdr: ^Exp) -> ^Exp {
	exp := new(Exp)
	exp^ = ExpCons {
		car = car,
		cdr = cdr,
	}
	return exp
}

new_proc :: proc(p: LispProc) -> ^Exp {
	exp := new(Exp)
	exp^ = ExpProc {
		pro = p,
	}
	return exp
}
