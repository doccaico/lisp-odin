package main

import "core:fmt"
import "core:math"
import "core:os"

Env :: struct {
	outer:    ^Env,
	bindings: map[string]^Exp,
}

standard_env :: proc() -> ^Env {
	env := new(Env)

	env.bindings["if"] = new_proc(if_proc, is_special = true)
	env.bindings["progn"] = new_proc(progn_proc, is_special = true)
	env.bindings["define"] = new_proc(define_proc, is_special = true)
	env.bindings["quote"] = new_proc(quote_proc, is_special = true)
	env.bindings["setf"] = new_proc(setf_proc, is_special = true)
	env.bindings["lambda"] = new_proc(lambda_proc, is_special = true)
	env.bindings["apply"] = new_proc(apply_proc, is_special = true)
	env.bindings["map"] = new_proc(map_proc, is_special = true)

	env.bindings["+"] = new_proc(add_proc, is_special = false)
	env.bindings["-"] = new_proc(sub_proc, is_special = false)
	// env.bindings["*"] = new_proc(mul)
	// env.bindings["/"] = new_proc(div)
	// env.bindings[">"] = new_proc(gt)
	// env.bindings[">="] = new_proc(gte)
	// env.bindings["<"] = new_proc(lt)
	// env.bindings["<="] = new_proc(lte)
	// env.bindings["="] = new_proc(eq)
	//
	// env.bindings["pi"] = new_float(math.PI)
	// env.bindings["sin"] = new_proc(sin)
	// env.bindings["cos"] = new_proc(cos)
	// env.bindings["sqrt"] = new_proc(sqrt)
	// env.bindings["abs"] = new_proc(abs)
	// env.bindings["expt"] = new_proc(expt)
	// env.bindings["max"] = new_proc(max)
	// env.bindings["min"] = new_proc(min)
	// env.bindings["round"] = new_proc(round)
	//
	env.bindings["list"] = new_proc(list_proc, is_special = false)
	// env.bindings["listp"] = new_proc(listp)
	// env.bindings["car"] = new_proc(car)
	// env.bindings["cdr"] = new_proc(cdr)
	env.bindings["cons"] = new_proc(cons_proc, is_special = false)
	// env.bindings["append"] = new_proc(append_)
	// env.bindings["null"] = new_proc(nullp)
	// env.bindings["print"] = new_proc(print)
	// env.bindings["equal"] = new_proc(equal)
	// env.bindings["length"] = new_proc(length)
	// env.bindings["not"] = new_proc(nullp) // same as null
	// env.bindings["numberp"] = new_proc(numberp)
	// env.bindings["functionp"] = new_proc(functionp)
	// env.bindings["symbolp"] = new_proc(symbolp)

	env.bindings["load"] = new_proc(load_proc, is_special = false)

	return env
}

find_env :: proc(env: ^Env, name: string) -> ^Env {
	current := env
	for current != nil {
		if val, ok := current.bindings[name]; ok {
			return current
		}
		current = current.outer
	}
	return nil
}

@(private = "file")
new_numeric_expr :: proc(flo: f64, is_all_int: bool) -> ^Exp {
	if is_all_int {
		return new_int(i64(flo))
	}
	return new_float(flo)
}

@(private = "file")
get_float :: proc(exp: ^Exp) -> (f64, bool) {
	#partial switch e in exp {
	case ExpNumber:
		return f64(e.num), true
	case ExpFloat:
		return e.flo, true
	}
	return 0.0, false
}

@(private = "file")
if_proc :: proc(args: [dynamic]^Exp, env: ^Env) -> (^Exp, string) {
	// (if T 1 2) -> 1
	// (if NIL 1 2) -> 2
	if len(args) != 3 {
		return nil, fmt.tprintf(
			"if requires exactly 3 arguments (test conseq alt), got %d",
			len(args),
		)
	}

	test := args[0]
	conseq := args[1]
	alt := args[2]
	test_res, test_res_err_msg := eval(test, env)
	if test_res_err_msg != "" {
		return nil, test_res_err_msg
	}
	is_true := true
	#partial switch tr in test_res {
	case ExpNil:
		is_true = false
	}
	if is_true {
		return eval(conseq, env)
	} else {
		return eval(alt, env)
	}
}

@(private = "file")
progn_proc :: proc(args: [dynamic]^Exp, env: ^Env) -> (^Exp, string) {
	// (progn (define x 1) (define y 2) (+ x y)) -> 3
	if len(args) == 0 {
		return new_nil(), ""
	}

	last_result: ^Exp = nil
	for form in args {
		err: string
		last_result, err = eval(form, env)
		if err != "" {
			return nil, err
		}
	}
	return last_result, ""
}


@(private = "file")
define_proc :: proc(args: [dynamic]^Exp, env: ^Env) -> (^Exp, string) {
	// (define x 10)
	// x -> 10
	if len(args) != 2 {
		return nil, "define requires exactly 2 argument"
	}
	if _, ok := args[0].(ExpSymbol); !ok {
		return nil, fmt.tprintf(
			"the argument to define, %s, is not a symbol",
			exp_to_string(args[0]),
		)
	}
	define_sym := args[0].(ExpSymbol).sym
	define_expr := args[1]

	define_err: string
	env.bindings[define_sym], define_err = eval(define_expr, env)
	if define_err != "" {
		return nil, define_err
	}
	return new_symbol(define_sym), ""
}

@(private = "file")
quote_proc :: proc(args: [dynamic]^Exp, env: ^Env) -> (^Exp, string) {
	// (quote exp)
	if len(args) != 1 {
		return nil, "quote requires exactly 1 argument"
	}
	return args[0], ""

}

@(private = "file")
setf_proc :: proc(args: [dynamic]^Exp, env: ^Env) -> (^Exp, string) {
	// (setf x 1) -> undefined symbol for setf: x
	// (define x 1)
	// (setf x 10)
	// x -> 10
	if len(args) != 2 {
		return nil, "setf requires exactly 2 arguments"
	}
	sym_expr, ok := args[0].(ExpSymbol)
	if !ok {
		return nil, fmt.tprintf(
			"the argument to setf, %s, is not a symbol",
			exp_to_string(args[0]),
		)
	}

	set_sym := sym_expr.sym
	set_expr := args[1]

	target_env := find_env(env, set_sym)
	if target_env == nil {
		return nil, fmt.tprintf("undefined symbol for setf: %s", set_sym)
	}

	val, set_err := eval(set_expr, env)
	if set_err != "" {
		return nil, set_err
	}

	target_env.bindings[set_sym] = val

	return val, ""
}

@(private = "file")
lambda_proc :: proc(args: [dynamic]^Exp, env: ^Env) -> (^Exp, string) {
	// ((lambda (a) (+ a 10)) 1) -> 11
	if len(args) < 2 {
		return nil, "lambda requires at least a parameter list and a body"
	}

	param_list_expr := args[0]
	param_slices, list_ok := flatten_list(param_list_expr)
	if !list_ok {
		return nil, "lambda parameters must be a proper list"
	}

	params := make([dynamic]string)
	for param in param_slices {
		sym_exp, sym_ok := param.(ExpSymbol)
		if !sym_ok {
			return nil, "lambda parameter must be a symbol"
		}
		append(&params, sym_exp.sym)
	}

	// Implicit progn
	body: ^Exp = nil
	if len(args) == 2 {
		body = args[1]
	} else {
		current_cdr: ^Exp = new_nil()

		for i := len(args) - 1; i >= 1; i -= 1 {
			current_cdr = new_cons(args[i], current_cdr)
		}

		body = new_cons(new_symbol("progn"), current_cdr)
	}

	return new_lambda(params, body, env), ""
}

@(private = "file")
apply_proc :: proc(args: [dynamic]^Exp, env: ^Env) -> (^Exp, string) {
	// (apply (lambda (a b) a) (list 1 2)) -> 1
	if len(args) != 2 {
		return nil, "apply requires exactly 2 arguments (a procedure/lambda and a list)"
	}

	procedure, pro_err := eval(args[0], env)
	if pro_err != "" {
		return nil, pro_err
	}

	#partial switch _ in procedure {
	case ExpProc, ExpLambda:
	case:
		return nil, "first argument to apply must be a procedure or lambda"
	}

	list_val, list_err := eval(args[1], env)
	if list_err != "" {
		return nil, list_err
	}

	param_slices, list_ok := flatten_list(list_val)
	if !list_ok {
		return nil, "second argument to apply must evaluate to a proper list"
	}

	invoke_args := make([dynamic]^Exp, 0, len(param_slices))
	for param in param_slices {
		append(&invoke_args, param)
	}

	val, invoke_err := invoke(procedure, invoke_args, env)
	if invoke_err != "" {
		return nil, invoke_err
	}

	return val, ""
}

@(private = "file")
map_proc :: proc(args: [dynamic]^Exp, env: ^Env) -> (^Exp, string) {
	// (map (lambda (a) (+ a 10)) (list 0 1 2)) -> (10 11 12)
	if len(args) != 2 {
		return nil, "map requires exactly 2 arguments (a procedure/lambda and a list)"
	}

	procedure, pro_err := eval(args[0], env)
	if pro_err != "" {
		return nil, pro_err
	}

	#partial switch _ in procedure {
	case ExpProc, ExpLambda:
	case:
		return nil, "first argument to map must be a procedure or lambda"
	}

	list_val, list_err := eval(args[1], env)
	if list_err != "" {
		return nil, list_err
	}

	param_slices, list_ok := flatten_list(list_val)
	if !list_ok {
		return nil, "second argument to map must evaluate to a proper list"
	}

	results := make([dynamic]^Exp, 0, len(param_slices))
	for elem in param_slices {
		invoke_args := make([dynamic]^Exp, 0, 1, context.temp_allocator)
		append(&invoke_args, elem)

		res_val, invoke_err := invoke(procedure, invoke_args, env)
		if invoke_err != "" {
			return nil, invoke_err
		}
		append(&results, res_val)
	}

	current_cdr: ^Exp = new_nil()
	for i := len(results) - 1; i >= 0; i -= 1 {
		current_cdr = new_cons(results[i], current_cdr)
	}

	return current_cdr, ""
}

@(private = "file")
add_proc :: proc(args: [dynamic]^Exp, env: ^Env) -> (^Exp, string) {
	// (+) -> 0
	// (+ 10) -> 10
	// (+ 10 10 10) -> 30
	if len(args) == 0 {
		return new_int(0), ""
	}

	sum := 0.0
	all_int := true

	for item in args {
		val, ok := get_float(item)
		if !ok {
			return nil, fmt.tprintf("%s is not a number or float", exp_to_string(item))
		}
		sum += val

		if _, is_int := item.(ExpNumber); !is_int {
			all_int = false
		}
	}

	return new_numeric_expr(sum, all_int), ""
}

@(private = "file")
sub_proc :: proc(args: [dynamic]^Exp, env: ^Env) -> (^Exp, string) {
	// (- 10) -> -10
	// (- 10 5 2) -> 3
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}

	first_val: f64
	first_ok: bool
	first_val, first_ok = get_float(args[0])
	if !first_ok {
		return nil, fmt.tprintf("%s is not a number or float", exp_to_string(args[0]))
	}

	_, all_int := args[0].(ExpNumber)
	if len(args) == 1 {
		// Invert the sign if there is a single argument
		return new_numeric_expr(-first_val, all_int), ""
	}

	sum := first_val

	for i := 1; i < len(args); i += 1 {
		item := args[i]
		val, ok := get_float(item)
		if !ok {
			return nil, fmt.tprintf("%s is not a number or float", exp_to_string(item))
		}
		sum -= val

		if _, is_int := item.(ExpNumber); !is_int {
			all_int = false
		}
	}

	return new_numeric_expr(sum, all_int), ""
}

// @(private = "file")
// mul :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	if len(args) == 0 {
// 		return new_int(1), ""
// 	}
// 	sum := get_float(args[0])
// 	all_int: bool
// 	if _, ok := args[0].(ExpNumber); ok {
// 		all_int = true
// 	}
//
// 	for i in 1 ..< len(args) {
// 		sum *= get_float(args[i])
// 		if _, is_number := args[0].(ExpNumber); !is_number {
// 			all_int = false
// 		}
// 	}
//
// 	return new_numeric_exp(sum, all_int), ""
// }
//
// @(private = "file")
// div :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	if len(args) == 0 {
// 		return nil, "invalid number of arguments: 0"
// 	}
// 	if len(args) == 1 {
// 		val := new(Exp)
// 		if get_float(args[0]) == 0.0 {
// 			#partial switch arg in args[0] {
// 			case ExpNumber:
// 				return nil, fmt.tprintf("operation was (/ 1 %s)", exp_to_string(new_int(arg.num)))
// 			case ExpFloat:
// 				return nil, fmt.tprintf(
// 					"operation was (/ 1 %s)",
// 					exp_to_string(new_float(arg.flo)),
// 				)
// 			}
// 		}
// 		_, is_number := args[0].(ExpNumber)
// 		return new_numeric_exp(1.0 / get_float(args[0]), is_number), ""
// 	}
//
// 	sum := get_float(args[0])
// 	all_int: bool
// 	if _, is_number := args[0].(ExpNumber); is_number {
// 		all_int = true
// 	}
//
// 	for i in 1 ..< len(args) {
// 		val := new(Exp)
// 		#partial switch arg in args[0] {
// 		case ExpNumber:
// 			val = new_int(arg.num)
// 		case ExpFloat:
// 			val = new_float(arg.flo)
// 		}
// 		if get_float(val) == 0.0 {
// 			real_sum := all_int ? new_int(i64(sum)) : new_float(sum)
// 			return nil, fmt.tprintf(
// 				"operation was (/ %s %s)",
// 				exp_to_string(real_sum),
// 				exp_to_string(val),
// 			)
// 		}
// 		sum /= get_float(args[i])
// 		if _, is_number := args[0].(ExpNumber); !is_number {
// 			all_int = false
// 		}
// 	}
//
// 	return new_numeric_exp(sum, all_int), ""
// }
//
// // Comparison operations (return T for true, NIL for false)
// // If there is only one argument, return T
// @(private = "file")
// gt :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// Example: (> 3 2 1) -> T, (> 3 2 10) -> NIL
// 	if len(args) == 0 {
// 		return nil, "invalid number of arguments: 0"
// 	}
// 	if len(args) == 1 {
// 		return new_true(), ""
// 	}
// 	for i in 0 ..< len(args) - 1 {
// 		left := get_float(args[i])
// 		right := get_float(args[i + 1])
// 		if left <= right {
// 			return new_nil(), ""
// 		}
// 	}
// 	return new_true(), ""
// }
//
// @(private = "file")
// gte :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// Example: (>= 3 2 2) -> T, (>= 3 2 10) -> NIL
// 	if len(args) == 0 {
// 		return nil, "invalid number of arguments: 0"
// 	}
// 	if len(args) == 1 {
// 		return new_true(), ""
// 	}
// 	for i in 0 ..< len(args) - 1 {
// 		left := get_float(args[i])
// 		right := get_float(args[i + 1])
// 		if left < right {
// 			return new_nil(), ""
// 		}
// 	}
// 	return new_true(), ""
// }
//
// @(private = "file")
// lt :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// Example: (< 1 2 3) -> T, (< 1 3 2) -> NIL
// 	if len(args) == 0 {
// 		return nil, "invalid number of arguments: 0"
// 	}
// 	if len(args) == 1 {
// 		return new_true(), ""
// 	}
// 	for i in 0 ..< len(args) - 1 {
// 		left := get_float(args[i])
// 		right := get_float(args[i + 1])
// 		if left >= right {
// 			return new_nil(), ""
// 		}
// 	}
// 	return new_true(), ""
// }
//
// @(private = "file")
// lte :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// Example: (<= 1 2 2) -> T, (<= 1 3 2) -> NIL
// 	if len(args) == 0 {
// 		return nil, "invalid number of arguments: 0"
// 	}
// 	if len(args) == 1 {
// 		return new_true(), ""
// 	}
// 	for i in 0 ..< len(args) - 1 {
// 		left := get_float(args[i])
// 		right := get_float(args[i + 1])
// 		if left > right {
// 			return new_nil(), ""
// 		}
// 	}
// 	return new_true(), ""
// }
//
// @(private = "file")
// eq :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// eq: Comparison for numeric values only
// 	if len(args) == 0 {
// 		return nil, "invalid number of arguments: 0"
// 	}
// 	if len(args) == 1 {
// 		return new_true(), "" // In SBCL, (= value) always returns T
// 	}
// 	first_val := get_float(args[0])
// 	for i in 1 ..< len(args) {
// 		val := get_float(args[i])
// 		if val != first_val {
// 			return new_nil(), ""
// 		}
// 	}
// 	return new_true(), ""
// }
//
// @(private = "file")
// sin :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	if len(args) != 1 {
// 		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
// 	}
// 	return new_float(math.sin_f64(get_float(args[0]))), ""
// }
//
// @(private = "file")
// cos :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	if len(args) != 1 {
// 		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
// 	}
// 	return new_float(math.cos_f64(get_float(args[0]))), ""
// }
//
// @(private = "file")
// sqrt :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	if len(args) != 1 {
// 		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
// 	}
// 	return new_float(math.sqrt_f64(get_float(args[0]))), ""
// }
//
// @(private = "file")
// abs :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	if len(args) != 1 {
// 		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
// 	}
// 	return new_float(math.abs(get_float(args[0]))), ""
// }
//
// @(private = "file")
// expt :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	if len(args) != 2 {
// 		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
// 	}
// 	all_int := true
// 	if _, is_number := args[0].(ExpNumber); !is_number {
// 		all_int = false
// 	}
// 	if _, is_number := args[1].(ExpNumber); !is_number {
// 		all_int = false
// 	}
// 	base := get_float(args[0])
// 	power := get_float(args[1])
// 	return new_numeric_exp(math.pow_f64(base, power), all_int), ""
// }
//
// @(private = "file")
// max :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// max: Returns the maximum value among the arguments
// 	// Example: (man 1 2 3) -> 3
// 	if len(args) == 0 {
// 		return nil, "invalid number of arguments: 0"
// 	}
// 	max_val := get_float(args[0])
// 	all_int: bool
// 	if _, is_number := args[0].(ExpNumber); is_number {
// 		all_int = true
// 	}
//
// 	for i in 1 ..< len(args) {
// 		val := get_float(args[i])
// 		if val > max_val {
// 			max_val = val
// 		}
// 		if _, is_number := args[i].(ExpNumber); !is_number {
// 			all_int = false
// 		}
// 	}
// 	return new_numeric_exp(max_val, all_int), ""
// }
//
// @(private = "file")
// min :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// min: Returns the minimum value among the arguments
// 	// Example: (min 10 1 20) -> 1
//
// 	if len(args) == 0 {
// 		return nil, "invalid number of arguments: 0"
// 	}
// 	min_val := get_float(args[0])
// 	all_int := false
// 	if _, is_number := args[0].(ExpNumber); is_number {
// 		all_int = true
// 	}
//
// 	for i in 1 ..< len(args) {
// 		val := get_float(args[i])
// 		if val < min_val {
// 			min_val = val
// 		}
// 		if _, is_number := args[i].(ExpNumber); !is_number {
// 			all_int = false
// 		}
// 	}
// 	return new_numeric_exp(min_val, all_int), ""
// }
//
// @(private = "file")
// round :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// round: Round a number to the nearest value
// 	// Example: (round 3.5) -> 4.0, (round 3.14) -> 3.0
// 	if len(args) != 1 {
// 		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
// 	}
// 	all_int := false
// 	if _, is_number := args[0].(ExpNumber); is_number {
// 		all_int = true
// 	}
// 	return new_numeric_exp(math.round_f64(get_float(args[0])), all_int), ""
// }
//
// @(private = "file")
list_proc :: proc(args: [dynamic]^Exp, env: ^Env) -> (^Exp, string) {
	// list: Create a new list containing all the arguments as its elements
	// Example (list 1 2 3) -> (1, 2, 3)
	head: ^Exp = new_nil()

	// Example: In the case of [1, 5, 4]
	// 1st iteration: Cons(4, Nil)
	// 2nd iteration: Cons(5, Cons(4, Nil))
	// 3rd iteration: Cons(1, Cons(5, Cons(4, Nil)))
	for i := len(args) - 1; i >= 0; i -= 1 {
		head = new_cons(args[i], cdr = head)
	}
	return head, ""
}

// @(private = "file")
// listp :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// list?: Returns T if the argument is a list, and NIL otherwise
// 	// Example (listp (list 1 2 3)) -> T, (listp (list)) -> T, (listp 42) -> NIL
// 	if len(args) != 1 {
// 		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
// 	}
// 	if li, is_list := args[0].(ExpList); is_list {
// 		return new_true(), ""
// 	}
// 	if ni, is_nil := args[0].(ExpNil); is_nil {
// 		return new_true(), ""
// 	}
// 	return new_nil(), ""
// }
//
// @(private = "file")
// car :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// car: Returns the first element of the list
// 	// Example: (car (list 1 2 3)) -> 1
// 	if len(args) != 1 {
// 		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
// 	}
// 	li: ExpList
// 	is_list := false
// 	if li, is_list = args[0].(ExpList); is_list {
// 		is_list = true
// 	}
//
// 	if len(li.list) == 0 {
// 		return new_nil(), ""
// 	}
// 	if !is_list {
// 		return nil, "car requires a list"
// 	}
// 	return li.list[0], ""
// }
//
// @(private = "file")
// cdr :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// cdr: Return the elements other than the first one as a new list
// 	// Example: (cdr '(1 2 3)) -> (2 3)
// 	if len(args) != 1 {
// 		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
// 	}
// 	// li: ExpList
// 	// is_list := false
// 	if _, ok := args[0].(ExpList); !ok {
//
// 		return nil, "cdr requires a list"
// 	}
// 	li := args[0].(ExpList).list
//
// 	if len(li) == 0 {
// 		return new_nil(), ""
// 	}
// 	pop_front(&li)
//
// 	return new_list(li), ""
// }
//
@(private = "file")
cons_proc :: proc(args: [dynamic]^Exp, env: ^Env) -> (^Exp, string) {
	// cons: Add an element to the beginning of the list
	// Example: (cons 1 2)      -> (1 . 2)
	//          (cons 1 (list)) -> (1)
	//          (cons 1 NIL)    -> (1)
	if len(args) != 2 {
		return nil, "cons: expected exactly 2 arguments"
	}

	car := args[0]
	cdr := args[1]

	return new_cons(car, cdr), ""
}

// @(private = "file")
// append_ :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// append: Combine multiple lists into one list
// 	// Example: (append (list 1 2) (list 3 4))    -> (1 2 3 4)
// 	//          (append (list 1) (list) (list 2)) -> (1 2)
// 	//          (append)                          -> NIL
// 	if len(args) == 0 {
// 		return new_nil(), ""
// 	}
//
// 	new_li: [dynamic]^Exp
//
// 	for arg in args {
// 		#partial switch s in arg {
// 		case ExpNil:
// 			// Skip NIL (empty list) so that it does not affect the concatenation
// 			continue
// 		case ExpList:
// 			for item in s.list {
// 				append(&new_li, item)
// 			}
// 		case:
// 			// If adhering strictly to specifications like those of Common Lisp,
// 			// the final argument can be an atom, forming a dotted pair; however, for the sake of simplicity,
// 			// we will initially limit this to the concatenation of lists.
// 			return nil, fmt.tprintf("The value %s is not of type LIST", exp_to_string(arg))
// 		}
// 	}
//
// 	if len(new_li) == 0 {
// 		return new_nil(), ""
// 	}
// 	return new_list(new_li), ""
// }
//
// @(private = "file")
// nullp :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// null: Returns T if the list is empty (contains 0 elements), and 0 (false) otherwise
// 	// Example: (null (list))   -> T
// 	//          (null NIL)      -> T
// 	//          (null (list 1)) -> NIL
// 	//          (null 42)       -> NIL
// 	if len(args) != 1 {
// 		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
// 	}
// 	ni: ExpNil
// 	is_nil := false
// 	if ni, is_nil = args[0].(ExpNil); is_nil {
// 		is_nil = true
// 	}
// 	if is_nil {
// 		return new_true(), ""
// 	}
// 	return new_nil(), ""
// }
//
// @(private = "file")
// print :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// print: print out
// 	if len(args) == 0 {
// 		return nil, "invalid number of arguments: 0"
// 	}
// 	fmt.println(exp_to_string(args[0]))
// 	return args[0], ""
// }
//
// is_equal :: proc(a: ^Exp, b: ^Exp) -> bool {
// 	if a == b {
// 		return true
// 	}
//
// 	#partial switch v_a in a {
// 	case ExpSymbol:
// 		v_b, ok := b.(ExpSymbol)
// 		if !ok {return false}
// 		return v_a.sym == v_b.sym
// 	case ExpNumber:
// 		v_b, ok := b.(ExpNumber)
// 		if !ok {return false}
// 		return v_a.num == v_b.num
// 	case ExpFloat:
// 		v_b, ok := b.(ExpFloat)
// 		if !ok {return false}
// 		return v_a.flo == v_b.flo
// 	case ExpString:
// 		v_b, ok := b.(ExpString)
// 		if !ok {return false}
// 		return v_a.str == v_b.str
// 	case ExpProc, ExpLambda:
// 		return a == b
// 	case ExpNil:
// 		v_b, ok := b.(ExpNil)
// 		if !ok {return false}
// 		return true
// 	case ExpTrue:
// 		v_b, ok := b.(ExpTrue)
// 		if !ok {return false}
// 		return true
// 	case ExpCons:
// 		v_b, ok := b.(ExpCons)
// 		if !ok {return false}
// 		return is_equal(v_a.car, v_b.car) == is_equal(v_a.cdr, v_b.cdr)
// 	case ExpList:
// 		v_b, ok := b.(ExpList)
// 		if !ok {return false}
//
// 		if len(v_a.list) != len(v_b.list) {return false}
//
// 		for i in 0 ..< len(v_a.list) {
// 			if !is_equal(v_a.list[i], v_b.list[i]) {
// 				return false
// 			}
// 		}
// 		return true
// 	}
// 	return false
// }
//
// @(private = "file")
// equal :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// equal: Comparison of structure and content
// 	if len(args) != 2 {
// 		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
// 	}
// 	if is_equal(args[0], args[1]) {
// 		return new_true(), ""
// 	}
// 	return new_nil(), ""
// }
//
// is_sequence :: proc(expr: ^Exp) -> bool {
// 	#partial switch e in expr {
// 	case ExpSymbol, ExpNumber, ExpFloat, ExpProc, ExpLambda, ExpTrue:
// 		return false
// 	case ExpList, ExpString, ExpCons:
// 		return true
// 	}
// 	unimplemented("Reached the end of is_sequence()")
// }
//
// @(private = "file")
// length :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// length: Returns the number of elements in the list
// 	if len(args) != 1 {
// 		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
// 	}
// 	if _, is_nil := args[0].(ExpNil); is_nil {
// 		return new_int(0), ""
// 	}
// 	fmt.println(args[0])
// 	if !is_sequence(args[0]) {
// 		return nil, fmt.tprintf("The value %s is not of type SEQUENCE", exp_to_string(args[0]))
// 	}
// 	if cons, is_cons := args[0].(ExpCons); is_cons {
// 		return nil, fmt.tprintf("The value %s is not of type LIST", exp_to_string(cons.cdr))
// 	}
// 	#partial switch arg in args[0] {
// 	case ExpList:
// 		return new_int(i64(len(arg.list))), ""
// 	case ExpString:
// 		return new_int(i64(len(arg.str))), ""
// 	}
// 	unimplemented("Reached the end of length()")
// }
//
// @(private = "file")
// numberp :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// numberp: Returns T if the argument is a number (an integer or a floating-point number), and NIL otherwise
// 	// Example: (number? 42) -> T, (number? 3.14) -> T, (number? (quote a)) -> NIL
// 	if len(args) != 1 {
// 		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
// 	}
//
// 	is_num := false
// 	#partial switch _ in args[0] {
// 	case ExpNumber, ExpFloat:
// 		is_num = true
// 	}
// 	if is_num {
// 		return new_true(), ""
// 	}
// 	return new_nil(), ""
// }
//
// @(private = "file")
// functionp :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// functionp: Returns T if the argument is a built-in function or a lambda, and NIL otherwise
// 	// Example: (procedure? +) -> T, (procedure? (lambda (x) x)) -> T, (procedure? 42) -> NIL
// 	if len(args) != 1 {
// 		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
// 	}
//
// 	is_func := false
// 	#partial switch _ in args[0] {
// 	case ExpProc, ExpLambda:
// 		is_func = true
// 	}
// 	if is_func {
// 		return new_true(), ""
// 	}
// 	return new_nil(), ""
// }
//
// @(private = "file")
// symbolp :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// symbolp: Returns T if the argument is a symbol, and NIL otherwise
// 	// Example: (symbol? (quote foo)) -> T, (symbol? 42) -> NIL
// 	if len(args) != 1 {
// 		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
// 	}
//
// 	is_sym := false
// 	#partial switch _ in args[0] {
// 	case ExpSymbol:
// 		is_sym = true
// 	}
// 	if is_sym {
// 		return new_true(), ""
// 	}
// 	return new_nil(), ""
// }


@(private = "file")
load_proc :: proc(args: [dynamic]^Exp, env: ^Env) -> (^Exp, string) {
	// Example: (load "examples\\demo.scm") or (load filename)
	if len(args) != 1 {
		return nil, "load requires exactly 1 argument (filename as a symbol or string)"
	}

	is_filename := false
	#partial switch _ in args[0] {
	case ExpSymbol, ExpString:
		is_filename = true
	}
	if !is_filename {
		return nil, "load requires exactly 1 argument (filename as a symbol or string)"
	}

	filename: string
	#partial switch arg in args[0] {
	case ExpSymbol:
		if s, ok := env.bindings[arg.sym].(ExpString); !ok {
			return nil, fmt.tprintf("%s is not string type", arg.sym)
		} else {
			filename = s.str
		}
	case ExpString:
		filename = arg.str
	}

	data, err := os.read_entire_file(filename, context.allocator)
	if err != nil {
		return nil, fmt.tprintf("cannot read a file: %s", filename)
	}

	r := init_reader(string(data))

	last_result: ^Exp = nil

	for {
		expr: ^Exp
		read_err: string
		if expr, read_err = read(&r); read_err != "" {
			return nil, read_err
		}

		if expr == nil {
			break
		}

		last_result, eval_err := eval(expr, env)
		if eval_err != "" {
			return nil, eval_err
		}

	}
	return last_result, ""
}
