package main

import "core:fmt"
import "core:math"
import "core:os"

Env :: struct {
	outer:    ^Env,
	bindings: map[string]^Expr,
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
	env.bindings["*"] = new_proc(mul_proc, is_special = false)
	env.bindings["/"] = new_proc(div_proc, is_special = false)

	env.bindings[">"] = new_proc(gt_proc, is_special = false)
	env.bindings[">="] = new_proc(gte_proc, is_special = false)
	env.bindings["<"] = new_proc(lt_proc, is_special = false)
	env.bindings["<="] = new_proc(lte_proc, is_special = false)
	env.bindings["="] = new_proc(equal_sign_proc, is_special = false)

	env.bindings["pi"] = new_float(math.PI)
	env.bindings["sin"] = new_proc(sin_proc, is_special = false)
	env.bindings["cos"] = new_proc(cos_proc, is_special = false)
	env.bindings["sqrt"] = new_proc(sqrt_proc, is_special = false)
	env.bindings["abs"] = new_proc(abs_proc, is_special = false)
	env.bindings["expt"] = new_proc(expt_proc, is_special = false)
	env.bindings["max"] = new_proc(max_proc, is_special = false)
	env.bindings["min"] = new_proc(min_proc, is_special = false)
	env.bindings["round"] = new_proc(round_proc, is_special = false)

	env.bindings["list"] = new_proc(list_proc, is_special = false)
	env.bindings["listp"] = new_proc(listp_proc, is_special = false)
	env.bindings["car"] = new_proc(car_proc, is_special = false)
	env.bindings["cdr"] = new_proc(cdr_proc, is_special = false)
	env.bindings["cons"] = new_proc(cons_proc, is_special = false)
	env.bindings["append"] = new_proc(append_proc, is_special = false)
	env.bindings["null"] = new_proc(null_proc, is_special = false)
	env.bindings["print"] = new_proc(print_proc, is_special = false)
	env.bindings["equal"] = new_proc(equal_proc, is_special = false)
	env.bindings["length"] = new_proc(length_proc, is_special = false)
	env.bindings["not"] = new_proc(null_proc, is_special = false) // same as null
	env.bindings["numberp"] = new_proc(numberp_proc, is_special = false)
	env.bindings["functionp"] = new_proc(functionp_proc, is_special = false)
	env.bindings["symbolp"] = new_proc(symbolp_proc, is_special = false)

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
new_numeric_expr :: #force_inline proc(flo: f64, is_all_int: bool) -> ^Expr {
	if is_all_int {
		return new_int(i64(flo))
	}
	return new_float(flo)
}

@(private = "file")
get_float :: #force_inline proc "contextless" (exp: ^Expr) -> (f64, bool) {
	#partial switch e in exp {
	case ExprNumber:
		return f64(e.num), true
	case ExprFloat:
		return e.flo, true
	}
	return 0.0, false
}

@(private = "file")
if_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
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
	test_res, test_res_err := eval(test, env)
	if test_res_err != "" {
		return nil, test_res_err
	}
	is_true := true
	#partial switch tr in test_res {
	case ExprNil:
		is_true = false
	}
	if is_true {
		return eval(conseq, env)
	} else {
		return eval(alt, env)
	}
}

@(private = "file")
progn_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (progn (define x 1) (define y 2) (+ x y)) -> 3
	if len(args) == 0 {
		return new_nil(), ""
	}

	last_result: ^Expr = nil
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
define_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (define x 10)
	// x -> 10
	if len(args) != 2 {
		return nil, "define requires exactly 2 argument"
	}
	if _, ok := args[0].(ExprSymbol); !ok {
		return nil, fmt.tprintf("the argument to define, %s, is not a symbol", to_string(args[0]))
	}
	define_sym := args[0].(ExprSymbol).sym
	define_expr := args[1]

	define_err: string
	env.bindings[define_sym], define_err = eval(define_expr, env)
	if define_err != "" {
		return nil, define_err
	}
	return new_symbol(define_sym), ""
}

@(private = "file")
quote_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (quote exp)
	if len(args) != 1 {
		return nil, "quote requires exactly 1 argument"
	}
	return args[0], ""

}

@(private = "file")
setf_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (setf x 1) -> undefined symbol for setf: x
	// (define x 1)
	// (setf x 10)
	// x -> 10
	if len(args) != 2 {
		return nil, "setf requires exactly 2 arguments"
	}
	sym_expr, ok := args[0].(ExprSymbol)
	if !ok {
		return nil, fmt.tprintf("the argument to setf, %s, is not a symbol", to_string(args[0]))
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
lambda_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
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
		sym_exp, sym_ok := param.(ExprSymbol)
		if !sym_ok {
			return nil, "lambda parameter must be a symbol"
		}
		append(&params, sym_exp.sym)
	}

	// Implicit progn
	body: ^Expr = nil
	if len(args) == 2 {
		body = args[1]
	} else {
		current_cdr: ^Expr = new_nil()

		for i := len(args) - 1; i >= 1; i -= 1 {
			current_cdr = new_cons(args[i], current_cdr)
		}

		body = new_cons(new_symbol("progn"), current_cdr)
	}

	return new_lambda(params, body, env), ""
}

@(private = "file")
apply_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (apply (lambda (a b) a) (list 1 2)) -> 1
	if len(args) != 2 {
		return nil, "apply requires exactly 2 arguments (a procedure/lambda and a list)"
	}

	procedure, pro_err := eval(args[0], env)
	if pro_err != "" {
		return nil, pro_err
	}

	#partial switch _ in procedure {
	case ExprProc, ExprLambda:
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

	invoke_args := make([dynamic]^Expr, 0, len(param_slices))
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
map_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (map (lambda (a) (+ a 10)) (list 0 1 2)) -> (10 11 12)
	if len(args) != 2 {
		return nil, "map requires exactly 2 arguments (a procedure/lambda and a list)"
	}

	procedure, pro_err := eval(args[0], env)
	if pro_err != "" {
		return nil, pro_err
	}

	#partial switch _ in procedure {
	case ExprProc, ExprLambda:
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

	results := make([dynamic]^Expr, 0, len(param_slices))
	for elem in param_slices {
		invoke_args := make([dynamic]^Expr, 0, 1, context.temp_allocator)
		append(&invoke_args, elem)

		res_val, invoke_err := invoke(procedure, invoke_args, env)
		if invoke_err != "" {
			return nil, invoke_err
		}
		append(&results, res_val)
	}

	current_cdr: ^Expr = new_nil()
	for i := len(results) - 1; i >= 0; i -= 1 {
		current_cdr = new_cons(results[i], current_cdr)
	}

	return current_cdr, ""
}

@(private = "file")
add_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
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
			return nil, fmt.tprintf("%s is not a number or float", to_string(item))
		}
		sum += val

		if _, is_int := item.(ExprNumber); !is_int {
			all_int = false
		}
	}

	return new_numeric_expr(sum, all_int), ""
}

@(private = "file")
sub_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (- 10) -> -10
	// (- 10 5 2) -> 3
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}

	first_val: f64
	first_ok: bool
	first_val, first_ok = get_float(args[0])
	if !first_ok {
		return nil, fmt.tprintf("%s is not a number or float", to_string(args[0]))
	}

	_, all_int := args[0].(ExprNumber)
	if len(args) == 1 {
		// Invert the sign if there is a single argument
		return new_numeric_expr(-first_val, all_int), ""
	}

	sum := first_val

	for i := 1; i < len(args); i += 1 {
		item := args[i]
		val, ok := get_float(item)
		if !ok {
			return nil, fmt.tprintf("%s is not a number or float", to_string(item))
		}
		sum -= val

		if _, is_int := item.(ExprNumber); !is_int {
			all_int = false
		}
	}

	return new_numeric_expr(sum, all_int), ""
}

@(private = "file")
mul_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (*) -> 1
	// (* 10) -> 10
	// (* 2 5 10) -> 100
	if len(args) == 0 {
		return new_int(1), ""
	}

	sum := 1.0
	all_int := true

	for item in args {
		val, ok := get_float(item)
		if !ok {
			return nil, fmt.tprintf("%s is not a number or float", to_string(item))
		}
		sum *= val

		if _, is_int := item.(ExprNumber); !is_int {
			all_int = false
		}
	}

	return new_numeric_expr(sum, all_int), ""
}

@(private = "file")
div_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (/ 0) -> division by zero
	// (/ 10) -> 0.1
	// (/ 10.5) -> 0.09523809523809523
	// (/ 10 5) -> 2
	// (/ 5 2) -> 2.5
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}

	first_val, first_ok := get_float(args[0])
	if !first_ok {
		return nil, fmt.tprintf("%s is not a number or float", to_string(args[0]))
	}

	if len(args) == 1 {
		if first_val == 0 {
			return nil, "division by zero"
		}
		return new_float(1.0 / first_val), ""
	}

	sum := first_val

	for i := 1; i < len(args); i += 1 {
		item := args[i]
		val, ok := get_float(item)
		if !ok {
			return nil, fmt.tprintf("%s is not a number or float", to_string(item))
		}

		if val == 0 {
			return nil, "division by zero"
		}

		sum /= val
	}

	int_part, frac_part := math.modf(sum)

	if frac_part == 0.0 {
		return new_numeric_expr(int_part, true), ""
	} else {
		return new_numeric_expr(sum, false), ""
	}
}

@(private = "file")
gt_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (> 3 2 1) -> T
	// (> 3 2 10) -> NIL
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}

	current_left, ok := get_float(args[0])
	if !ok {
		return nil, fmt.tprintf("%s is not a number or float", to_string(args[0]))
	}

	if len(args) == 1 {
		return new_true(), ""
	}

	for i := 1; i < len(args); i += 1 {
		right_val, right_ok := get_float(args[i])
		if !right_ok {
			return nil, fmt.tprintf("%s is not a number or float", to_string(args[i]))
		}

		if current_left <= right_val {
			return new_nil(), ""
		}

		current_left = right_val
	}

	return new_true(), ""
}

@(private = "file")
gte_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (>= 3 2 2) -> T
	// (>= 3 2 10) -> NIL
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}

	current_left, ok := get_float(args[0])
	if !ok {
		return nil, fmt.tprintf("%s is not a number or float", to_string(args[0]))
	}

	if len(args) == 1 {
		return new_true(), ""
	}

	for i := 1; i < len(args); i += 1 {
		right_val, right_ok := get_float(args[i])
		if !right_ok {
			return nil, fmt.tprintf("%s is not a number or float", to_string(args[i]))
		}

		if current_left < right_val {
			return new_nil(), ""
		}

		current_left = right_val
	}

	return new_true(), ""
}

@(private = "file")
lt_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (< 1 2 3) -> T
	// (< 1 3 2) -> NIL
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}

	current_left, ok := get_float(args[0])
	if !ok {
		return nil, fmt.tprintf("%s is not a number or float", to_string(args[0]))
	}

	if len(args) == 1 {
		return new_true(), ""
	}

	for i := 1; i < len(args); i += 1 {
		right_val, right_ok := get_float(args[i])
		if !right_ok {
			return nil, fmt.tprintf("%s is not a number or float", to_string(args[i]))
		}

		if current_left >= right_val {
			return new_nil(), ""
		}

		current_left = right_val
	}

	return new_true(), ""
}

@(private = "file")
lte_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (<= 1 2 2) -> T
	// (<= 1 3 2) -> NIL
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}

	current_left, ok := get_float(args[0])
	if !ok {
		return nil, fmt.tprintf("%s is not a number or float", to_string(args[0]))
	}

	if len(args) == 1 {
		return new_true(), ""
	}

	for i := 1; i < len(args); i += 1 {
		right_val, right_ok := get_float(args[i])
		if !right_ok {
			return nil, fmt.tprintf("%s is not a number or float", to_string(args[i]))
		}

		if current_left > right_val {
			return new_nil(), ""
		}

		current_left = right_val
	}

	return new_true(), ""
}

@(private = "file")
equal_sign_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (= 2 2 2) -> T
	// (= 2 2 3) -> NIL
	// (= 2 2.0) -> T
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}

	current_left, ok := get_float(args[0])
	if !ok {
		return nil, fmt.tprintf("%s is not a number or float", to_string(args[0]))
	}

	// In SBCL, (= value) always returns T
	if len(args) == 1 {
		return new_true(), ""
	}

	for i := 1; i < len(args); i += 1 {
		right_val, right_ok := get_float(args[i])
		if !right_ok {
			return nil, fmt.tprintf("%s is not a number or float", to_string(args[i]))
		}

		if current_left != right_val {
			return new_nil(), ""
		}

		current_left = right_val
	}

	return new_true(), ""
}

@(private = "file")
sin_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}

	val, ok := get_float(args[0])
	if !ok {
		return nil, fmt.tprintf("%s is not a number or float", to_string(args[0]))
	}

	return new_float(math.sin(val)), ""
}

@(private = "file")
cos_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}

	val, ok := get_float(args[0])
	if !ok {
		return nil, fmt.tprintf("%s is not a number or float", to_string(args[0]))
	}

	return new_float(math.cos(val)), ""
}

@(private = "file")
sqrt_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}

	val, ok := get_float(args[0])
	if !ok {
		return nil, fmt.tprintf("%s is not a number or float", to_string(args[0]))
	}

	return new_float(math.sqrt(val)), ""
}

@(private = "file")
abs_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}

	val, ok := get_float(args[0])
	if !ok {
		return nil, fmt.tprintf("%s is not a number or float", to_string(args[0]))
	}

	return new_float(math.abs(val)), ""
}

@(private = "file")
expt_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (expt 2 10) -> 1024
	if len(args) != 2 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}

	base, base_ok := get_float(args[0])
	if !base_ok {
		return nil, fmt.tprintf("%s is not a number or float", to_string(args[0]))
	}

	power, power_ok := get_float(args[1])
	if !power_ok {
		return nil, fmt.tprintf("%s is not a number or float", to_string(args[1]))
	}

	val := math.pow(base, power)
	int_part, frac_part := math.modf(val)

	if frac_part == 0.0 {
		return new_numeric_expr(int_part, true), ""
	} else {
		return new_numeric_expr(val, false), ""
	}
}

@(private = "file")
max_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (max 5) -> 5
	// (max 1 5 3) -> 5
	// (max 1 5.0 3) -> 5.0
	// (man 1 2 3) -> 3
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}

	max_val, ok := get_float(args[0])
	if !ok {
		return nil, fmt.tprintf("%s is not a number or float", to_string(args[0]))
	}

	max_item := args[0]

	if len(args) == 1 {
		_, is_int := max_item.(ExprNumber)
		return new_numeric_expr(max_val, is_int), ""
	}

	_, all_int := max_item.(ExprNumber)

	for i := 1; i < len(args); i += 1 {
		item := args[i]
		val, val_ok := get_float(item)
		if !val_ok {
			return nil, fmt.tprintf("%s is not a number or float", to_string(item))
		}

		if _, is_int := item.(ExprNumber); !is_int {
			all_int = false
		}

		if val > max_val {
			max_val = val
			max_item = item
		}
	}

	return new_numeric_expr(max_val, all_int), ""
}

@(private = "file")
min_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (min 5) -> 5
	// (min 1 5 3) -> 1
	// (min 1 0.5 3) -> 0.5
	// (min 1 2 3) -> 1
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}

	min_val, ok := get_float(args[0])
	if !ok {
		return nil, fmt.tprintf("%s is not a number or float", to_string(args[0]))
	}

	min_item := args[0]

	if len(args) == 1 {
		_, is_int := min_item.(ExprNumber)
		return new_numeric_expr(min_val, is_int), ""
	}

	_, all_int := min_item.(ExprNumber)

	for i := 1; i < len(args); i += 1 {
		item := args[i]
		val, val_ok := get_float(item)
		if !val_ok {
			return nil, fmt.tprintf("%s is not a number or float", to_string(item))
		}

		if _, is_int := item.(ExprNumber); !is_int {
			all_int = false
		}

		if val < min_val {
			min_val = val
			min_item = item
		}
	}

	return new_numeric_expr(min_val, all_int), ""
}

@(private = "file")
round_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (round 3.4) -> 3
	// (round 3.6) -> 4
	// (round -3.6) -> -4
	if len(args) != 1 {
		return nil, fmt.tprintf(
			"invalid number of arguments: %d (round requires exactly 1 argument)",
			len(args),
		)
	}

	val, ok := get_float(args[0])
	if !ok {
		return nil, fmt.tprintf("%s is not a number or float", to_string(args[0]))
	}

	rounded_val := math.round(val)

	return new_numeric_expr(rounded_val, true), ""
}

@(private = "file")
list_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (list 1 2 3) -> (1, 2, 3)
	head: ^Expr = new_nil()

	// In the case of [1, 5, 4]
	// 1st iteration: Cons(4, Nil)
	// 2nd iteration: Cons(5, Cons(4, Nil))
	// 3rd iteration: Cons(1, Cons(5, Cons(4, Nil)))
	for i := len(args) - 1; i >= 0; i -= 1 {
		head = new_cons(args[i], cdr = head)
	}
	return head, ""
}

@(private = "file")
listp_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (listp (list 1 2 3)) -> T
	// (listp (list)) -> T
	// (listp 42) -> NIL
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}

	target := args[0]

	#partial switch _ in target {
	case ExprCons, ExprNil:
		return new_true(), ""
	case:
		return new_nil(), ""
	}
}

@(private = "file")
car_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (car (list 1 2 3)) -> 1
	// (car NIL) -> NIL
	// (car (list)) -> NIL
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}

	target := args[0]

	#partial switch t in target {
	case ExprCons:
		return t.car, ""
	case ExprNil:
		return new_nil(), ""
	case:
		return nil, fmt.tprintf("%s is not a list", to_string(target))
	}
}

@(private = "file")
cdr_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (cdr '(1 2 3)) -> (2 3)
	// (cdr (cons 1 2)) -> 2
	// (cdr NIL) -> NIL
	// (cdr (list)) -> NIL
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}

	target := args[0]

	#partial switch t in target {
	case ExprCons:
		return t.cdr, ""
	case ExprNil:
		return new_nil(), ""
	case:
		return nil, fmt.tprintf("%s is not a list", to_string(target))
	}
}

@(private = "file")
cons_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (cons 1 2) -> (1 . 2)
	// (cons 1 (list)) -> (1)
	// (cons 1 NIL) -> (1)
	if len(args) != 2 {
		return nil, "cons: expected exactly 2 arguments"
	}

	car := args[0]
	cdr := args[1]

	return new_cons(car, cdr), ""
}

@(private = "file")
append_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (append (list 1 2) (list 3 4)) -> (1 2 3 4)
	// (append (list 1) (list) (list 2)) -> (1 2)
	// (append) -> NIL
	if len(args) == 0 {
		return new_nil(), ""
	}

	if len(args) == 1 {
		return args[0], ""
	}

	res := args[len(args) - 1]

	for i := len(args) - 2; i >= 0; i -= 1 {
		current_list := args[i]

		param_slices, list_ok := flatten_list(current_list)
		if !list_ok {
			return nil, fmt.tprintf("%s is not a proper list", to_string(current_list))
		}

		for j := len(param_slices) - 1; j >= 0; j -= 1 {
			car := param_slices[j]
			cdr := res
			res = new_cons(car, cdr)
		}
	}

	return res, ""
}

@(private = "file")
null_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (null (list)) -> T
	// (null NIL) -> T
	// (null (list 1)) -> NIL
	// (null 42) -> NIL
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}

	target := args[0]

	#partial switch t in target {
	case ExprNil:
		return new_true(), ""
	case:
		return new_nil(), ""
	}
}

@(private = "file")
print_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (print 1) -> 1 1
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}
	fmt.println(to_string(args[0]))
	return args[0], ""
}

@(private = "file")
is_equal :: proc(a: ^Expr, b: ^Expr) -> bool {
	if a == b {
		return true
	}

	#partial switch v_a in a {
	case ExprSymbol:
		v_b, ok := b.(ExprSymbol)
		return ok && v_a.sym == v_b.sym
	case ExprNumber:
		v_b, ok := b.(ExprNumber)
		return ok && v_a.num == v_b.num
	case ExprFloat:
		v_b, ok := b.(ExprFloat)
		return ok && v_a.flo == v_b.flo
	case ExprString:
		v_b, ok := b.(ExprString)
		return ok && v_a.str == v_b.str
	case ExprProc, ExprLambda:
		return a == b
	case ExprNil:
		_, ok := b.(ExprNil)
		return ok
	case ExprTrue:
		_, ok := b.(ExprTrue)
		return ok
	case ExprCons:
		v_b, ok := b.(ExprCons)
		if !ok {
			return false
		}
		return is_equal(v_a.car, v_b.car) && is_equal(v_a.cdr, v_b.cdr)
	}
	return false
}

@(private = "file")
equal_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (equal (list 1) (list 1)) -> T
	// (equal (list 1) (list 1 2)) -> NIL
	if len(args) != 2 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}
	if is_equal(args[0], args[1]) {
		return new_true(), ""
	}
	return new_nil(), ""
}

@(private = "file")
length_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (length (list 1 2 3)) -> 3
	// (length "abcde") -> 5
	// (length NIL) -> 0
	// (length (list)) -> 0
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}

	target := args[0]

	#partial switch t in target {
	case ExprCons:
		slices, ok := flatten_list(target)
		if !ok {
			return nil, "length parameters must be a proper list"
		}
		return new_int(i64(len(slices))), ""
	case ExprString:
		return new_int(i64(len(t.str))), ""
	case ExprNil:
		return new_int(0), ""
	case:
		return nil, fmt.tprintf("The value %s is not of type SEQUENCE", to_string(target))
	}
}

@(private = "file")
numberp_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (numberp 42) -> T
	// (numberp 3.14) -> T
	// (numberp (quote a)) -> NIL
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}

	target := args[0]

	#partial switch _ in target {
	case ExprNumber, ExprFloat:
		return new_true(), ""
	case:
		return new_nil(), ""
	}
}

@(private = "file")
functionp_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (functionp +) -> T
	// (functionp (lambda (x) x)) -> T
	// (functionp 42) -> NIL
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}

	target := args[0]

	#partial switch _ in target {
	case ExprProc, ExprLambda:
		return new_true(), ""
	case:
		return new_nil(), ""
	}
}

@(private = "file")
symbolp_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (symbolp (quote foo)) -> T
	// (symbolp 42) -> NIL
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}

	target := args[0]

	#partial switch _ in target {
	case ExprSymbol:
		return new_true(), ""
	case:
		return new_nil(), ""
	}
}

@(private = "file")
load_proc :: proc(args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	// (load "examples\\demo.scm")
	// or
	// (define filepath "examples\\demo.scm")
	// (load filepath)
	if len(args) != 1 {
		return nil, "load requires exactly 1 argument (filename as a symbol or string)"
	}

	target := args[0]

	is_filename := false
	#partial switch _ in target {
	case ExprSymbol, ExprString:
		is_filename = true
	}
	if !is_filename {
		return nil, "load requires exactly 1 argument (filename as a symbol or string)"
	}

	filename: string
	#partial switch arg in target {
	case ExprSymbol:
		if s, ok := env.bindings[arg.sym].(ExprString); !ok {
			return nil, fmt.tprintf("%s is not string type", arg.sym)
		} else {
			filename = s.str
		}
	case ExprString:
		filename = arg.str
	}

	data, err := os.read_entire_file(filename, context.allocator)
	if err != nil {
		return nil, fmt.tprintf("cannot read a file: %s", filename)
	}

	r := init_reader(string(data))

	last_result: ^Expr = nil

	for {
		expr: ^Expr
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
