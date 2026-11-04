package main

import "core:bufio"
import "core:fmt"
import "core:os"

repl :: proc(prompt: string, global_env: ^Env) {
	fmt.printfln(
		"The standard environment has been initialized. Number of registrations: %d",
		len(global_env.bindings),
	)

	stream := os.to_reader(os.stdin)

	scanner: bufio.Scanner
	bufio.scanner_init(&scanner, stream)

	fmt.print(prompt)

	for bufio.scan(&scanner) {
		if err := bufio.scanner_error(&scanner); err != nil {
			fmt.printfln("Error reading input: %v", err)
			break
		}

		input := bufio.scanner_text(&scanner)

		if len(input) == 0 {
			continue
		}

		if input == "(:q)" || input == "(:quit)" {
			break
		}

		r := init_reader(input)

		last_eval_expr: ^Exp = nil
		has_eval_result := false

		for {

			read_expr: ^Exp
			read_err_msg: string

			if read_expr, read_err_msg = read(&r); read_err_msg != "" {
				fmt.println(read_err_msg)
				has_eval_result = false
				fmt.print(prompt)
				break
			}

			if read_expr == nil {
				break
			}

			if eval_expr, eval_err_msg := eval(read_expr, global_env); eval_err_msg != "" {
				fmt.println(eval_err_msg)
				has_eval_result = false
				break
			} else {
				last_eval_expr = eval_expr
				has_eval_result = true
			}
		}

		if has_eval_result && last_eval_expr != nil {
			fmt.println(exp_to_string(last_eval_expr))
			fmt.print(prompt)
		}
	}
}
