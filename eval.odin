package main

import "core:fmt"
import "core:os"

eval :: proc(expr: ^Expr, env: ^Env) -> (^Expr, string) {
	switch e in expr {
	case ExprSymbol:
		if target_env := find_env(env, e.sym); target_env != nil {
			return target_env.bindings[e.sym], ""
		} else {
			return nil, fmt.tprintf("undefined symbol: %s", to_string(expr))
		}
	case ExprNumber, ExprFloat, ExprString, ExprProc, ExprLambda, ExprTrue, ExprNil:
		return expr, ""
	case ExprCons:
		first, cons_err := eval(e.car, env)
		if cons_err != "" {
			return nil, cons_err
		}

		pro: ^Expr
		pro_err: string
		if pro, pro_err = eval(first, env); pro_err != "" {
			return nil, pro_err
		}

		list, list_ok := flatten_list(e.cdr)
		if !list_ok {
			return nil, "improper list (dot notation) cannot be evaluated as function arguments"
		}

		args := make([dynamic]^Expr)

		is_special_form := false
		if p, ok := pro.(ExprProc); ok {
			if p.is_special {
				is_special_form = true
			}
		}

		if is_special_form {
			for i in 0 ..< len(list) {
				append(&args, list[i])
			}
		} else {
			for i in 0 ..< len(list) {
				if elem, err := eval(list[i], env); err != "" {
					return nil, err
				} else {
					append(&args, elem)
				}
			}
		}
		return invoke(pro, args, env)
	}

	return nil, "reached the end of eval()"
}

invoke :: proc(procedure: ^Expr, args: [dynamic]^Expr, env: ^Env) -> (^Expr, string) {
	#partial switch p in procedure {
	case ExprProc:
		if res, err_msg := p.pro(args, env); err_msg != "" {
			return nil, err_msg
		} else {
			return res, ""
		}
	case ExprLambda:
		if len(args) != len(p.params) {
			return nil, fmt.tprintf(
				"wrong number of arguments: expected %d, got %d",
				len(p.params),
				len(args),
			)
		}
		new_env := new(Env)
		new_env.outer = p.closure
		new_env.bindings = make(map[string]^Expr)
		for i in 0 ..< len(p.params) {
			new_env.bindings[p.params[i]] = args[i]
		}
		return eval(p.body, new_env)
	case:
		return nil, fmt.tprintf("not a procedure or lambda: %s", to_string(procedure))
	}
}
