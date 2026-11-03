package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import vmem "core:mem/virtual"
import "core:os"

is_repl := false

HELP_MESSAGE :: `Usage: odin-lisp FILENAME
  -r:         REPL
  -h, --help: show a help message
	`

main :: proc() {
	arena: vmem.Arena
	arena_err := vmem.arena_init_growing(&arena)
	if arena_err != nil {
		print_and_exit("Failed to init arena")
	}
	arena_allocator := vmem.arena_allocator(&arena)
	defer vmem.arena_destroy(&arena)

	context.allocator = arena_allocator

	if len(os.args) == 1 || (os.args[1] == "-h" || os.args[1] == "--help") {
		fmt.print(HELP_MESSAGE)
		return
	}

	global_env := standard_env()

	if os.args[1] == "-r" || os.args[1] == "--repl" {
		is_repl = true
		repl("lisp-odin> ", global_env)
		return
	}

	filename := os.args[1]
	data, read_err := os.read_entire_file(filename, context.allocator)
	if read_err != nil {
		print_and_exit("Cannot read a file: %s", filename)
	}

	r := init_reader(string(data))

	for {
		expr: ^Exp
		msg: string
		if expr, msg = read(&r); msg != "" {
			fmt.println(msg)
			os.exit(1)
		}

		if expr == nil {
			break
		}

		fmt.println(expr^)
		// fmt.println(eval(ast, global_env))
		if expr, msg := eval(expr, global_env); msg != "" {
			fmt.println(msg)
			os.exit(1)
			// if is_repl {
			// 	fmt.println(msg)
			// } else {
			// 	fmt.println(msg)
			// 	os.exit(1)
			// }
		} else {
			fmt.println(exp_to_string(expr))
		}
		free_all(context.temp_allocator)
	}
}
