package main

import "core:fmt"
import "core:os"

eval :: proc(exp: ^Exp, env: ^Env) -> (^Exp, string) {
	#partial switch e in exp {
	case ExpSymbol:
		if target_env := find_env(env, e.sym); target_env != nil {
			return target_env.bindings[e.sym], ""
		} else {
			return nil, fmt.tprintf("undefined symbol: %s", exp_to_string(exp))
		}
	case ExpNumber, ExpFloat, ExpString, ExpProc, ExpLambda, ExpTrue, ExpNil:
		return exp, ""
	case ExpList:
		if len(e.list) == 0 {
			return exp, ""
		}
		first := e.list[0]
		if symbol, ok := first.(ExpSymbol); ok {

			if symbol.sym == "if" { 	// (if test conseq alt)
				if len(e.list) != 4 {
					return nil, fmt.tprintf(
						"if requires exactly 3 arguments (test conseq alt), got %d",
						len(e.list) - 1,
					)
				}
				test := e.list[1]
				conseq := e.list[2]
				alt := e.list[3]
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
			} else if symbol.sym == "progn" { 	// (progn (...) (...)...)
				forms: [dynamic]^Exp

				#partial switch li in exp {
				case ExpList:
					if len(li.list) <= 1 {
						return new_nil(), ""
					}
					for i := 1; i < len(li.list); i += 1 {
						append(&forms, li.list[i])
					}
				}

				if len(forms) == 0 {
					return new_nil(), ""
				}

				last_result: ^Exp = nil
				for form in forms {
					err: string
					last_result, err = eval(form, env) // ここで初めて評価する！
					if err != "" {
						return nil, err
					}
				}
				return last_result, ""

			} else if symbol.sym == ":load" { 	// (:load "examples\\demo.scm") or (load filename)
				if len(e.list) <= 1 {
					return nil,
						":load requires exactly 1 argument (filename as a symbol or string)"
				}

				is_filename := false
				#partial switch _ in e.list[1] {
				case ExpSymbol, ExpString:
					is_filename = true
				}

				if !is_filename {
					return nil,
						":load requires exactly 1 argument (filename as a symbol or string)"
				}

				filename: string
				#partial switch arg in e.list[1] {
				case ExpSymbol:
					if s, ok := env.bindings[arg.sym].(ExpString); !ok {
						return nil, fmt.tprintf("%s is not string type", arg.sym)
					} else {
						filename = s.str
					}
				case ExpString:
					filename = arg.str
				}

				data, read_err := os.read_entire_file(filename, context.allocator)
				if read_err != nil {
					return nil, fmt.tprintf("Cannot read a file: %s", filename)
				}

				r := init_reader(string(data))

				last_result: ^Exp = nil
				err: string

				for {
					expr: ^Exp
					msg: string
					if expr, msg = read(&r); msg != "" {
						fmt.println(msg)
						return nil, ""
					}

					if expr == nil {
						break
					}

					last_result, err = eval(expr, env)
					if err != "" {
						return nil, err
					}

				}
				return last_result, ""

			} else if symbol.sym == "define" { 	// (define symbol exp)
				if len(e.list) != 3 {
					return nil, "define requires exactly 2 argument"
				}
				if _, ok := e.list[1].(ExpSymbol); !ok {
					return nil, fmt.tprintf(
						"the argument to define, %s, is not a symbol",
						exp_to_string(e.list[1]),
					)
				}
				define_sym := e.list[1].(ExpSymbol).sym
				define_expr := e.list[2]

				define_err: string
				env.bindings[define_sym], define_err = eval(define_expr, env)
				if define_err != "" {
					return nil, define_err
				}
				return new_symbol(define_sym), ""

			} else if symbol.sym == "quote" { 	// (quote exp)
				if len(e.list) != 2 {
					return nil, "quote requires exactly 1 argument"
				}
				return e.list[1], ""

			} else if symbol.sym == "set!" { 	// (set! symbol exp)
				if len(e.list) != 3 {
					return nil, "set! requires exactly 2 argument"
				}
				if _, ok := e.list[1].(ExpSymbol); !ok {
					return nil, fmt.tprintf(
						"the argument to set!, %s, is not a symbol",
						exp_to_string(e.list[1]),
					)
				}
				set_sym := e.list[1].(ExpSymbol).sym
				set_expr := e.list[2]
				target_env := find_env(env, set_sym)
				if target_env != nil {
					set_err: string
					target_env.bindings[set_sym], set_err = eval(set_expr, env)
					if set_err != "" {
						return nil, set_err
					}
					return new_symbol(set_sym), ""
				} else {
					return nil, fmt.tprintf("undefined symbol for set!: %s", symbol)
				}

			} else if symbol.sym == "lambda" { 	// (lambda (params...) body...)
				if len(e.list) < 3 {
					return nil, "lambda requires at least a parameter list and a body"
				}
				param_list := e.list[1]
				if _, ok := param_list.(ExpList); !ok {
					return nil, "lambda parameters must be a list"
				}
				params: [dynamic]string
				for param in param_list.(ExpList).list {
					if _, ok := param.(ExpSymbol); !ok {
						return nil, "lambda parameter must be a symbol"
					}
					append(&params, param.(ExpSymbol).sym)
				}

				// Implicit progn
				body: ^Exp = nil

				if len(e.list) == 3 {
					body = e.list[2]
				} else {
					progn_list: [dynamic]^Exp
					append(&progn_list, new_symbol("progn"))
					for i := 2; i < len(e.list); i += 1 {
						append(&progn_list, e.list[i])
					}
					body = new_list(progn_list)
				}
				return new_lambda(params, body, env), ""

			} else if symbol.sym == "apply" { 	// (apply proc list)
				if len(e.list) != 3 {
					return nil, "apply requires exactly 2 arguments (a procedure and a list)"
				}
				procedure, pro_err := eval(e.list[1], env)
				if pro_err != "" {
					return nil, pro_err
				}
				list_expr, list_expr_err := eval(e.list[2], env)
				if list_expr_err != "" {
					return nil, list_expr_err
				}
				if _, ok := list_expr.(ExpList); !ok {
					return nil, "second argument to apply must be a list"
				}
				return invoke(procedure, list_expr.(ExpList).list)

			} else if symbol.sym == "map" {

				if len(e.list) != 3 {
					return nil, "map requires exactly 2 arguments: a procedure and a list"
				}

				procedure, pro_err := eval(e.list[1], env)
				if pro_err != "" {
					return nil, pro_err
				}

				list_arg, list_expr_err := eval(e.list[2], env)
				if list_expr_err != "" {
					return nil, list_expr_err
				}

				result_elements: [dynamic]^Exp

				#partial switch lst in list_arg^ {
				case ExpNil:
					return new_nil(), ""
				case ExpList:
					for item in lst.list {
						args := make([dynamic]^Exp)
						append(&args, item)
						res, err := invoke(procedure, args)
						if err != "" {
							return nil, err
						}
						append(&result_elements, res)
					}
				case ExpCons:
					current := list_arg
					main_loop: for current != nil {
						#partial switch c in current^ {
						case ExpCons:
							args := make([dynamic]^Exp)
							append(&args, c.car)
							res, err := invoke(procedure, args)
							if err != "" {
								return nil, err
							}
							append(&result_elements, res)
							current = c.cdr
						case ExpNil:
							break main_loop
						case ExpList:
							if len(c.list) == 0 {
								break main_loop
							}
							return nil, "map: invalid list structure (dotted pair encountered)"
						case:
							return nil, "map: second argument must be a proper list"
						}
					}
				case:
					fmt.println("DEBUG: lst is type:", lst)
					return nil, "second argument to map must be a list"
				}
				return new_list(result_elements), ""
			}

		}

		procedure: ^Exp
		msg: string
		ok: bool
		if procedure, msg = eval(first, env); msg != "" {
			return nil, msg
		}
		args := make([dynamic]^Exp)
		for i in 1 ..< len(e.list) {
			if p, m := eval(e.list[i], env); m != "" {
				return nil, m
			} else {
				append(&args, p)
			}
		}
		return invoke(procedure, args)
	}

	unimplemented("Reached the end of eval()")
}

invoke :: proc(procedure: ^Exp, args: [dynamic]^Exp) -> (^Exp, string) {
	#partial switch p in procedure {
	case ExpProc:
		if res, err_msg := p.pro(args); err_msg != "" {
			return nil, err_msg
		} else {
			return res, ""
		}
	case ExpLambda:
		if len(args) != len(p.params) {
			return nil, fmt.tprintf(
				"wrong number of arguments: expected %d, got %d",
				len(p.params),
				len(args),
			)
		}
		new_env := new(Env)
		new_env.outer = p.closure
		new_env.bindings = make(map[string]^Exp)
		for i in 0 ..< len(p.params) {
			new_env.bindings[p.params[i]] = args[i]
		}
		return eval(p.body, new_env)
	case:
		return nil, fmt.tprintf("not a procedure or lambda: %s", exp_to_string(procedure))
	}

	unimplemented("Reached the end of invoke()")
}
