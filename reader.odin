package main

import "core:fmt"
import "core:strconv"
import "core:strings"

Reader :: struct {
	input:         string,
	position:      int,
	read_position: int,
	ch:            byte,
}

// Initialize the lexical analyzer / reader
init_reader :: proc(input: string) -> Reader {
	r := Reader {
		input         = input,
		position      = 0,
		read_position = 0,
		ch            = '\x00',
	}
	// Advance once to set the initial character in 'ch'
	next_char(&r)
	return r
}

read :: proc(r: ^Reader) -> (^Expr, string) {
	skip_whitespace(r, skip_comment = true)

	if r.ch == '"' {
		// Return a string object
		s, err := read_string(r)
		if err != "" {
			return nil, err
		}
		return new_str(s), ""
	} else if r.ch == '(' {
		// Consume '('
		next_char(r)
		// Delegate list parsing to the specialized function
		if expr, msg := read_list(r); msg != "" {
			return nil, msg
		} else {
			return expr, ""
		}
	} else if r.ch == ')' {
		return nil, "Unexpected closing parenthesis ')'"
	} else if r.ch == '\x00' {
		// End of input reached
		return nil, ""
	}
	// If it's not a quote or parenthesis, it's guaranteed to be an atom
	return read_atom(r), ""
}

// Advance one character (consume input)
@(private = "file")
next_char :: proc(r: ^Reader) {
	if r.read_position >= len(r.input) {
		// Nul character signifies end of input
		r.ch = '\x00'
	} else {
		r.ch = r.input[r.read_position]
	}
	r.position = r.read_position
	r.read_position += 1
}

@(private = "file")
is_delimiter :: #force_inline proc(ch: byte) -> bool {
	// Whitespace, parentheses, quotes, or EOF are delimiters
	switch ch {
	case ' ', '\t', '\r', '\n', '(', ')', '"', '\x00':
		return true
	case:
		return false
	}
}

// Skip whitespaces and comments (lines starting with ';')
@(private = "file")
skip_whitespace :: proc(r: ^Reader, skip_comment: bool = false) {
	for {
		// Skip standard whitespaces
		switch r.ch {
		case ' ', '\t', '\r', '\n':
			next_char(r)
			continue
		}

		// Skip comment line if ';' is encountered
		if skip_comment && r.ch == ';' {
			// Consume characters until we hit a newline (\n, \r) or End of Input (\0)
			for r.ch != '\n' && r.ch != '\r' && r.ch != '\x00' {
				next_char(r)
			}
			continue
		}
		// If the current character is neither a whitespace nor a comment start, stop skipping
		break
	}
}

// Parse string literals
@(private = "file")
read_string :: proc(r: ^Reader) -> (string, string) {
	// Skip the starting double quote
	next_char(r)
	sb := strings.builder_make()

	for {
		if r.ch == '"' {
			// Consume the closing quote and advance
			next_char(r)
			break
		}

		if r.ch == '\x00' {
			return "", "Unclosed string literal"
		}


		if r.ch == '\\' {
			// Consume '\\'
			next_char(r)
			if r.ch == '\x00' {
				return "", "Unclosed string literal after escape"
			}

			switch r.ch {
			case 'n':
				strings.write_byte(&sb, '\n')
			case 't':
				strings.write_byte(&sb, '\t')
			case 'r':
				strings.write_byte(&sb, '\r')
			case '\\':
				strings.write_byte(&sb, '\\')
			case '"':
				strings.write_byte(&sb, '"')
			case:
				strings.write_byte(&sb, r.ch)
			}
		} else {
			strings.write_byte(&sb, r.ch)
		}
		next_char(r)
	}
	return strings.to_string(sb), ""
}

@(private = "file")
read_list :: proc(r: ^Reader) -> (^Expr, string) {
	elements := make([dynamic]^Expr)

	has_dot := false
	var_cdr: ^Expr = nil

	for {
		skip_whitespace(r, skip_comment = true)

		// 閉じカッコが見つかったらループ終了
		if r.ch == ')' {
			next_char(r) // ')' を消費
			break
		}

		// 入力の終端に達してしまった場合はエラー
		if r.ch == '\x00' {
			return nil, "Expected closing parenthesis ')', but reached EOF"
		}

		// ドット対（ドット表現）の処理（オプション：必要なければこのifブロックは削除してOKです）
		if r.ch == '.' {
			// 次の文字を確認するため、先読み or 進める
			next_char(r)
			skip_whitespace(r, skip_comment = true)

			if r.ch == ')' {
				return nil, "S-expression syntax error: unexpected ')' after '.'"
			}

			// ドットの後は、cdr となる最後の1要素だけを読み込む
			final_expr, err := read(r)
			if err != "" {
				return nil, err
			}

			skip_whitespace(r, skip_comment = true)
			if r.ch != ')' {
				return nil, "S-expression syntax error: expected ')' after dot notation value"
			}

			has_dot = true
			var_cdr = final_expr
			next_char(r) // ')' を消費
			break
		}

		expr, err := read(r)
		if err != "" {
			return nil, err
		}

		append(&elements, expr)
	}

	// From this point, convert the elements into a nested structure of `ExprCons` / `ExprNil`
	head: ^Expr = nil
	if has_dot {
		head = var_cdr
	} else {
		head = new_nil()
	}

	// (1 2 3) -> Cons(3, Nil) -> Cons(2, Cons(3, Nil))...
	for i := len(elements) - 1; i >= 0; i -= 1 {
		head = new_cons(elements[i], head)
	}

	return head, ""
}

@(private = "file")
read_atom :: proc(r: ^Reader) -> ^Expr {
	start_pos := r.position

	for !is_delimiter(r.ch) {
		next_char(r)
	}
	token := r.input[start_pos:r.position]

	switch token {
	case "t", "T":
		return new_true()
	case "nil", "NIL":
		return new_nil()
	}

	i_num, i_ok := strconv.parse_i64_maybe_prefixed(token)
	if i_ok {
		return new_int(i_num)
	}

	f_num, f_ok := strconv.parse_f64(token)
	if f_ok {
		return new_float(f_num)
	}

	return new_symbol(token)
}
