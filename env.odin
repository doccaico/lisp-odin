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
	env.bindings["cdr"] = new_proc(cdr)
	env.bindings["cons"] = new_proc(cons)
	env.bindings["append"] = new_proc(append_)
	env.bindings["null"] = new_proc(nullp)
	env.bindings["print"] = new_proc(print)
	env.bindings["equal"] = new_proc(equal)
	env.bindings["length"] = new_proc(length)
	// env.bindings["map"] = new_proc(map_)
	env.bindings["not"] = new_proc(nullp) // same as null
	env.bindings["numberp"] = new_proc(numberp)
	env.bindings["functionp"] = new_proc(functionp)
	env.bindings["symbolp"] = new_proc(symbolp)

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
	}
	panic(fmt.tprintf("expected a number or float, but got: %s", exp_to_string(exp)))
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
	for i in 0 ..< len(args) - 1 {
		left := get_float(args[i])
		right := get_float(args[i + 1])
		if left <= right {
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
	for i in 0 ..< len(args) - 1 {
		left := get_float(args[i])
		right := get_float(args[i + 1])
		if left < right {
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
	for i in 0 ..< len(args) - 1 {
		left := get_float(args[i])
		right := get_float(args[i + 1])
		if left >= right {
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
	for i in 0 ..< len(args) - 1 {
		left := get_float(args[i])
		right := get_float(args[i + 1])
		if left > right {
			return new_nil(), ""
		}
	}
	return new_true(), ""
}

@(private = "file")
eq :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// eq: Comparison for numeric values only
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}
	if len(args) == 1 {
		return new_true(), "" // In SBCL, (= value) always returns T
	}
	first_val := get_float(args[0])
	for i in 1 ..< len(args) {
		val := get_float(args[i])
		if val != first_val {
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
		return nil, "car requires a list"
	}
	return li.list[0], ""
}

@(private = "file")
cdr :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// cdr: Return the elements other than the first one as a new list
	// Example: (cdr '(1 2 3)) -> (2 3)
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}
	// li: ExpList
	// is_list := false
	if _, ok := args[0].(ExpList); !ok {

		return nil, "cdr requires a list"
	}
	li := args[0].(ExpList).list

	if len(li) == 0 {
		return new_nil(), ""
	}
	pop_front(&li)

	return new_list(li), ""
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

@(private = "file")
print :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// print: print out
	if len(args) == 0 {
		return nil, "invalid number of arguments: 0"
	}
	fmt.println(exp_to_string(args[0]))
	return args[0], ""
}

is_equal :: proc(a: ^Exp, b: ^Exp) -> bool {
	if a == b {
		return true
	}

	#partial switch v_a in a {
	case ExpSymbol:
		v_b, ok := b.(ExpSymbol)
		if !ok {return false}
		return v_a.sym == v_b.sym
	case ExpNumber:
		v_b, ok := b.(ExpNumber)
		if !ok {return false}
		return v_a.num == v_b.num
	case ExpFloat:
		v_b, ok := b.(ExpFloat)
		if !ok {return false}
		return v_a.flo == v_b.flo
	case ExpString:
		v_b, ok := b.(ExpString)
		if !ok {return false}
		return v_a.str == v_b.str
	case ExpProc, ExpLambda:
		return a == b
	case ExpNil:
		v_b, ok := b.(ExpNil)
		if !ok {return false}
		return true
	case ExpTrue:
		v_b, ok := b.(ExpTrue)
		if !ok {return false}
		return true
	case ExpCons:
		v_b, ok := b.(ExpCons)
		if !ok {return false}
		return is_equal(v_a.car, v_b.car) == is_equal(v_a.cdr, v_b.cdr)
	case ExpList:
		v_b, ok := b.(ExpList)
		if !ok {return false}

		if len(v_a.list) != len(v_b.list) {return false}

		for i in 0 ..< len(v_a.list) {
			if !is_equal(v_a.list[i], v_b.list[i]) {
				return false
			}
		}
		return true
	}
	return false
}

@(private = "file")
equal :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// equal: Comparison of structure and content
	if len(args) != 2 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}
	if is_equal(args[0], args[1]) {
		return new_true(), ""
	}
	return new_nil(), ""
}

is_sequence :: proc(expr: ^Exp) -> bool {
	#partial switch e in expr {
	case ExpSymbol, ExpNumber, ExpFloat, ExpProc, ExpLambda, ExpTrue:
		return false
	case ExpList, ExpString, ExpCons:
		return true
	}
	unimplemented("Reached the end of is_sequence()")
}

@(private = "file")
length :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// length: Returns the number of elements in the list
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}
	if _, is_nil := args[0].(ExpNil); is_nil {
		return new_int(0), ""
	}
	fmt.println(args[0])
	if !is_sequence(args[0]) {
		return nil, fmt.tprintf("The value %s is not of type SEQUENCE", exp_to_string(args[0]))
	}
	if cons, is_cons := args[0].(ExpCons); is_cons {
		return nil, fmt.tprintf("The value %s is not of type LIST", exp_to_string(cons.cdr))
	}
	#partial switch arg in args[0] {
	case ExpList:
		return new_int(i64(len(arg.list))), ""
	case ExpString:
		return new_int(i64(len(arg.str))), ""
	}
	unimplemented("Reached the end of length()")
}


// @(private = "file")
// map_ :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
// 	// map: Returns a new list obtained by applying a procedure to each element of the list
// 	if len(args) != 2 {
// 		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
// 	}
//
// 	procedure := args[0]
// 	list_expr := args[1]
//
// 	is_proc := false
// 	#partial switch _ in procedure {
// 	case ExpProc, ExpLambda:
// 		is_proc = true
// 	}
// 	if !is_proc {
// 		return nil, fmt.tprintf("first argument to map must be a proc or lambda")
// 	}
// 	if _, is_list := list_expr.(ExpList); !is_list {
// 		return nil, fmt.tprintf("second argument to map must be a list")
// 	}
//
// 	mapped_list: [dynamic]^Exp
// 	for item in list_expr.(ExpList).list {
// 		item_list: [dynamic]^Exp
// 		append(&item_list, item)
//
// 		expr, err := invoke(procedure, item_list)
// 		if err != "" {
// 			return nil, err
// 		}
// 		append(&mapped_list, expr)
// 	}
// 	return new_list(mapped_list), ""
// }

@(private = "file")
numberp :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// numberp: Returns T if the argument is a number (an integer or a floating-point number), and NIL otherwise
	// Example: (number? 42) -> T, (number? 3.14) -> T, (number? (quote a)) -> NIL
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}

	is_num := false
	#partial switch _ in args[0] {
	case ExpNumber, ExpFloat:
		is_num = true
	}
	if is_num {
		return new_true(), ""
	}
	return new_nil(), ""
}

@(private = "file")
functionp :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// functionp: Returns T if the argument is a built-in function or a lambda, and NIL otherwise
	// Example: (procedure? +) -> T, (procedure? (lambda (x) x)) -> T, (procedure? 42) -> NIL
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}

	is_func := false
	#partial switch _ in args[0] {
	case ExpProc, ExpLambda:
		is_func = true
	}
	if is_func {
		return new_true(), ""
	}
	return new_nil(), ""
}

@(private = "file")
symbolp :: proc(args: [dynamic]^Exp) -> (^Exp, string) {
	// symbolp: Returns T if the argument is a symbol, and NIL otherwise
	// Example: (symbol? (quote foo)) -> T, (symbol? 42) -> NIL
	if len(args) != 1 {
		return nil, fmt.tprintf("invalid number of arguments: %d", len(args))
	}

	is_sym := false
	#partial switch _ in args[0] {
	case ExpSymbol:
		is_sym = true
	}
	if is_sym {
		return new_true(), ""
	}
	return new_nil(), ""
}
