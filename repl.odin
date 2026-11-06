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
			fmt.print(prompt)
			continue
		}

		r := init_reader(input)

		last_eval_expr: ^Expr = nil
		has_eval_result := false

		for {

			read_expr: ^Expr
			read_err: string

			if read_expr, read_err = read(&r); read_err != "" {
				has_eval_result = false
				fmt.println(read_err)
				break
			}

			if read_expr == nil {
				break
			}

			if eval_expr, eval_err := eval(read_expr, global_env); eval_err != "" {
				has_eval_result = false
				fmt.println(eval_err)
				break
			} else {
				last_eval_expr = eval_expr
				has_eval_result = true
			}
		}

		if has_eval_result && last_eval_expr != nil {
			fmt.println(to_string(last_eval_expr))
		}

		fmt.print(prompt)
	}
}
