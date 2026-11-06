package main

import "core:fmt"
import vmem "core:mem/virtual"
import "core:os"

HELP_MESSAGE :: `Usage: odin-lisp FILENAME
  -r, --repl:       REPL
  -h, --help:       show a help message
	`

main :: proc() {
	arena: vmem.Arena
	arena_err := vmem.arena_init_growing(&arena)
	assert(arena_err == nil)
	arena_allocator := vmem.arena_allocator(&arena)
	defer vmem.arena_destroy(&arena)

	context.allocator = arena_allocator
	defer free_all(context.temp_allocator)

	if len(os.args) == 1 || (os.args[1] == "-h" || os.args[1] == "--help") {
		fmt.print(HELP_MESSAGE)
		return
	}

	global_env := standard_env()

	if os.args[1] == "-r" || os.args[1] == "--repl" {
		repl("lisp-odin> ", global_env)
		return
	}

	filename := os.args[1]
	data, read_err := os.read_entire_file(filename, context.allocator)
	if read_err != nil {
		fmt.eprintfln("Cannot read a file: %s", filename)
		os.exit(1)
	}

	r := init_reader(string(data))

	for {
		expr: ^Expr
		read_err: string
		if expr, read_err = read(&r); read_err != "" {
			fmt.println(read_err)
			os.exit(1)
		}

		if expr == nil {
			break
		}

		if _, eval_err := eval(expr, global_env); eval_err != "" {
			fmt.println(eval_err)
			os.exit(1)
		}
	}
}
