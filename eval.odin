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
				is_true: bool
				#partial switch tr in test_res {
				case ExpNumber:
					is_true = tr.num != 0
				case ExpFloat:
					is_true = tr.flo != 0.0
				case ExpList:
					is_true = len(tr.list) > 0
				case:
					is_true = true
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
					filename = arg.sym
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
			} else if symbol.sym == "quote" { 	// (quote exp)
			} else if symbol.sym == "set!" { 	// (set! symbol exp)
			} else if symbol.sym == "lambda" { 	// (lambda (params...) body)
			} else if symbol.sym == "apply" { 	// (apply proc list)
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

	// return nil
	unreachable()
}

// @(private = "file")
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
	unreachable()
}
