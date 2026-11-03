package main

import "core:fmt"
import "core:math"

Env :: struct {
	outer:    ^Env,
	bindings: map[string]^Exp,
}

standard_env :: proc() -> ^Env {
	env := new(Env)
	env.bindings["+"] = new_proc(plus)
	env.bindings["-"] = new_proc(minus)
	env.bindings["*"] = new_proc(mul)
	env.bindings["/"] = new_proc(div)
	env.bindings[">"] = new_proc(gt)
	env.bindings[">="] = new_proc(gte)
	env.bindings["<"] = new_proc(lt)
	env.bindings["<="] = new_proc(lte)
	env.bindings["="] = new_proc(eq)

	env.bindings["pi"] = new_float(math.PI)
	env.bindings["sin"] = new_proc(sin)
	env.bindings["cos"] = new_proc(cos)
	env.bindings["sqrt"] = new_proc(sqrt)
	env.bindings["abs"] = new_proc(abs)
	env.bindings["expt"] = new_proc(expt)
	env.bindings["max"] = new_proc(max)
	env.bindings["min"] = new_proc(min)
	env.bindings["round"] = new_proc(round)

	env.bindings["list"] = new_proc(list)
	env.bindings["listp"] = new_proc(listp)
	env.bindings["car"] = new_proc(car)
	env.bindings["cons"] = new_proc(cons)
	env.bindings["append"] = new_proc(append_)
	env.bindings["null"] = new_proc(nullp)
	env.bindings["progn"] = new_proc(progn)

	return env
}

find_env :: proc(env: ^Env, name: string) -> ^Env {
	current := env
	for current != nil {
		if val, ok := env.bindings[name]; ok {
			return current
		}
		current = current.outer
	}
	return nil
}

@(private = "file")
new_numeric_exp :: proc(flo: f64, is_all_int: bool) -> ^Exp {
	if is_all_int {
		return new_int(i64(flo))
	}
	return new_float(flo)
}

@(private = "file")
get_float :: proc(exp: ^Exp) -> f64 {
	#partial switch e in exp {
	case ExpNumber:
		return f64(e.num)
	case ExpFloat:
		return e.flo
	case:
		print_and_exit("expected a number, but got: %s", exp_to_string(exp))
	}
	unreachable()
}

@(private = "file")
plus :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	if len(args) == 0 {
		return new_int(0), ""
	}
	sum := get_float(args[0])
	all_int: bool
	if _, ok := args[0].(ExpNumber); ok {
		all_int = true
	}

	for i in 1 ..< len(args) {
		sum += get_float(args[i])
		if _, ok := args[0].(ExpNumber); !ok {
			all_int = false
		}
	}

	return new_numeric_exp(sum, all_int), ""
}

@(private = "file")
minus :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}
	if len(args) == 1 { 	// Invert the sign if there is a single argument
		_, is_number := args[0].(ExpNumber)
		return new_numeric_exp(-get_float(args[0]), is_number), ""
	}

	sum := get_float(args[0])
	all_int: bool
	if _, is_number := args[0].(ExpNumber); is_number {
		all_int = true
	}

	for i in 1 ..< len(args) {
		sum -= get_float(args[i])
		if _, is_number := args[0].(ExpNumber); !is_number {
			all_int = false
		}
	}

	return new_numeric_exp(sum, all_int), ""
}

@(private = "file")
mul :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	if len(args) == 0 {
		return new_int(1), ""
	}
	sum := get_float(args[0])
	all_int: bool
	if _, ok := args[0].(ExpNumber); ok {
		all_int = true
	}

	for i in 1 ..< len(args) {
		sum *= get_float(args[i])
		if _, is_number := args[0].(ExpNumber); !is_number {
			all_int = false
		}
	}

	return new_numeric_exp(sum, all_int), ""
}

@(private = "file")
div :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}
	if len(args) == 1 {
		val := new(Exp)
		if get_float(args[0]) == 0.0 {
			#partial switch arg in args[0] {
			case ExpNumber:
				return nil, fmt.tprintf("operation was (/ 1 %s)", exp_to_string(new_int(arg.num)))
			case ExpFloat:
				return nil, fmt.tprintf(
					"operation was (/ 1 %s)",
					exp_to_string(new_float(arg.flo)),
				)
			}
		}
		_, is_number := args[0].(ExpNumber)
		return new_numeric_exp(1.0 / get_float(args[0]), is_number), ""
	}

	sum := get_float(args[0])
	all_int: bool
	if _, is_number := args[0].(ExpNumber); is_number {
		all_int = true
	}

	for i in 1 ..< len(args) {
		val := new(Exp)
		#partial switch arg in args[0] {
		case ExpNumber:
			val = new_int(arg.num)
		case ExpFloat:
			val = new_float(arg.flo)
		}
		if get_float(val) == 0.0 {
			real_sum := all_int ? new_int(i64(sum)) : new_float(sum)
			return nil, fmt.tprintf(
				"operation was (/ %s %s)",
				exp_to_string(real_sum),
				exp_to_string(val),
			)
		}
		sum /= get_float(args[i])
		if _, is_number := args[0].(ExpNumber); !is_number {
			all_int = false
		}
	}

	return new_numeric_exp(sum, all_int), ""
}

// Comparison operations (return T for true, NIL for false)
// If there is only one argument, return T
@(private = "file")
gt :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// Example: (> 3 2 1) -> T, (> 3 2 10) -> NIL
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}
	if len(args) == 1 {
		return new_true(), ""
	}
	for i in 1 ..< len(args) - 1 {
		if get_float(args[i]) <= get_float(args[i + 1]) {
			return new_nil(), ""
		}
	}
	return new_true(), ""
}

@(private = "file")
gte :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// Example: (>= 3 2 2) -> T, (>= 3 2 10) -> NIL
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}
	if len(args) == 1 {
		return new_true(), ""
	}
	for i in 1 ..< len(args) - 1 {
		if get_float(args[i]) < get_float(args[i + 1]) {
			return new_nil(), ""
		}
	}
	return new_true(), ""
}

@(private = "file")
lt :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// Example: (< 1 2 3) -> T, (< 1 3 2) -> NIL
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}
	if len(args) == 1 {
		return new_true(), ""
	}
	for i in 1 ..< len(args) - 1 {
		if get_float(args[i]) >= get_float(args[i + 1]) {
			return new_nil(), ""
		}
	}
	return new_true(), ""
}

@(private = "file")
lte :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// Example: (<= 1 2 2) -> T, (<= 1 3 2) -> NIL
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}
	if len(args) == 1 {
		return new_true(), ""
	}
	for i in 1 ..< len(args) - 1 {
		if get_float(args[i]) > get_float(args[i + 1]) {
			return new_nil(), ""
		}
	}
	return new_true(), ""
}

@(private = "file")
eq :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}
	if len(args) == 1 {
		return new_true(), "" // In SBCL, (= value) always returns T
	}
	first_val := get_float(args[0])
	for i in 1 ..< len(args) {
		if get_float(args[i]) != first_val {
			return new_nil(), ""
		}
	}
	return new_true(), ""
}

@(private = "file")
sin :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}
	return new_float(math.sin_f64(get_float(args[0]))), ""
}

@(private = "file")
cos :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}
	return new_float(math.cos_f64(get_float(args[0]))), ""
}

@(private = "file")
sqrt :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}
	return new_float(math.sqrt_f64(get_float(args[0]))), ""
}

@(private = "file")
abs :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}
	return new_float(math.abs(get_float(args[0]))), ""
}

@(private = "file")
expt :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	if len(args) != 2 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}
	all_int := true
	if _, is_number := args[0].(ExpNumber); !is_number {
		all_int = false
	}
	if _, is_number := args[1].(ExpNumber); !is_number {
		all_int = false
	}
	base := get_float(args[0])
	power := get_float(args[1])
	return new_numeric_exp(math.pow_f64(base, power), all_int), ""
}

@(private = "file")
max :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// max: Returns the maximum value among the arguments
	// Example: (man 1 2 3) -> 3
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}
	max_val := get_float(args[0])
	all_int: bool
	if _, is_number := args[0].(ExpNumber); is_number {
		all_int = true
	}

	for i in 1 ..< len(args) {
		val := get_float(args[i])
		if val > max_val {
			max_val = val
		}
		if _, is_number := args[i].(ExpNumber); !is_number {
			all_int = false
		}
	}
	return new_numeric_exp(max_val, all_int), ""
}

@(private = "file")
min :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// min: Returns the minimum value among the arguments
	// Example: (min 10 1 20) -> 1

	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}
	min_val := get_float(args[0])
	all_int := false
	if _, is_number := args[0].(ExpNumber); is_number {
		all_int = true
	}

	for i in 1 ..< len(args) {
		val := get_float(args[i])
		if val < min_val {
			min_val = val
		}
		if _, is_number := args[i].(ExpNumber); !is_number {
			all_int = false
		}
	}
	return new_numeric_exp(min_val, all_int), ""
}

@(private = "file")
round :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// round: Round a number to the nearest value
	// Example: (round 3.5) -> 4.0, (round 3.14) -> 3.0
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}
	all_int := false
	if _, is_number := args[0].(ExpNumber); is_number {
		all_int = true
	}
	return new_numeric_exp(math.round_f64(get_float(args[0])), all_int), ""
}

@(private = "file")
list :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// list: Create a new list containing all the arguments as its elements
	// Example (list 1 2 3) -> (1, 2, 3)
	if len(args) == 0 {
		return new_nil(), ""
	}
	return new_list(args), ""
}

@(private = "file")

listp :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// list?: Returns T if the argument is a list, and NIL otherwise
	// Example (listp (list 1 2 3)) -> T, (listp (list)) -> T, (listp 42) -> NIL
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}
	if li, is_list := args[0].(ExpList); is_list {
		return new_true(), ""
	}
	if ni, is_nil := args[0].(ExpNil); is_nil {
		return new_true(), ""
	}
	return new_nil(), ""
}

@(private = "file")
car :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// car: Returns the first element of the list
	// Example: (car (list 1 2 3)) -> 1
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}
	li: ExpList
	is_list := false
	if li, is_list = args[0].(ExpList); is_list {
		is_list = true
	}

	if len(li.list) == 0 {
		return new_nil(), ""
	}

	if !is_list {
		return nil, fmt.tprintf(
			"The value %s is not of type LIST when binding LIST",
			exp_to_string(li.list[0]),
		)
	}
	return li.list[0], ""
}

@(private = "file")
cons :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// cons: Add an element to the beginning of the list
	// Example: (cons 1 '(2 3)) -> (1 2 3)
	//          (cons 1 2)      -> (1 . 2)
	//          (cons 1 (list)) -> (1)
	//          (cons 1 NIL)    -> (1)
	if len(args) != 2 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}
	if ni, is_nil := args[1].(ExpNil); is_nil {
		new_li: [dynamic]^Exp
		append(&new_li, args[0])
		return new_list(new_li), ""
	}
	return new_cons(args[0], args[1]), ""
}

@(private = "file")
append_ :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// append: Combine multiple lists into one list
	// Example: (append (list 1 2) (list 3 4))    -> (1 2 3 4)
	//          (append (list 1) (list) (list 2)) -> (1 2)
	//          (append)                          -> NIL
	if len(args) == 0 {
		return new_nil(), ""
	}

	new_li: [dynamic]^Exp

	for arg in args {
		#partial switch s in arg {
		case ExpNil:
			// Skip NIL (empty list) so that it does not affect the concatenation
			continue
		case ExpList:
			for item in s.list {
				append(&new_li, item)
			}
		case:
			// If adhering strictly to specifications like those of Common Lisp,
			// the final argument can be an atom, forming a dotted pair; however, for the sake of simplicity,
			// we will initially limit this to the concatenation of lists.
			return nil, fmt.tprintf("The value %s is not of type LIST", exp_to_string(arg))
		}
	}

	if len(new_li) == 0 {
		return new_nil(), ""
	}
	return new_list(new_li), ""
}

@(private = "file")
nullp :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// null: Returns T if the list is empty (contains 0 elements), and 0 (false) otherwise
	// Example: (null (list))   -> T
	//          (null NIL)      -> T
	//          (null (list 1)) -> NIL
	//          (null 42)       -> NIL
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}
	ni: ExpNil
	is_nil := false
	if ni, is_nil = args[0].(ExpNil); is_nil {
		is_nil = true
	}
	if is_nil {
		return new_true(), ""
	}
	return new_nil(), ""
}

// TODO
@(private = "file")
progn :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// progn: Evaluates the arguments in order, then evaluates and returns the final element
	if len(args) == 0 {
		return new_nil(), ""
	}

	last_result: ^Exp = nil

	for form in args {
		err: string
		last_result, err = eval(form)
		if err != "" {
			return nil, err
		}
	}
	return last_result, ""
}
