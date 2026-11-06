package main

import "core:fmt"
import "core:math"
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
	return read_atom(r)
}

// Advance one character (consume input)
@(private = "file")
next_char :: proc "contextless" (r: ^Reader) {
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
is_delimiter :: #force_inline proc "contextless" (ch: byte) -> bool {
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
skip_whitespace :: proc "contextless" (r: ^Reader, skip_comment: bool = false) {
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

	sb, err := strings.builder_make()

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

		// Terminate loop if a closing parenthesis is found
		if r.ch == ')' {
			next_char(r) // Consume ')'
			break
		}

		// Error if the end of input is reached unexpectedly
		if r.ch == '\x00' {
			return nil, "Expected closing parenthesis ')', but reached EOF"
		}

		// Handle dotted pairs (dot notation) - Optional: you can delete this if not needed
		if r.ch == '.' {
			// Check next character by peeking or advancing
			next_char(r)
			skip_whitespace(r, skip_comment = true)

			if r.ch == ')' {
				return nil, "S-expression syntax error: unexpected ')' after '.'"
			}

			// After the dot, read only the final element which serves as the cdr
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
			next_char(r) // Consume ')'
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
convert_prefixed_token :: proc(s: string) -> string {
	if len(s) >= 2 && s[0] == '#' {
		sb, err := strings.builder_make()
		prefix: string

		switch s[1] {
		case 'd', 'D':
			prefix = "0d"
		case 'x', 'X':
			prefix = "0x"
		case 'o', 'O':
			prefix = "0o"
		case 'b', 'B':
			prefix = "0b"
		}
		if s[2] == '+' {
			strings.write_string(&sb, prefix)
			strings.write_string(&sb, s[3:])
		} else if s[2] == '-' {
			strings.write_string(&sb, "-")
			strings.write_string(&sb, prefix)
			strings.write_string(&sb, s[3:])
		} else {
			strings.write_string(&sb, prefix)
			strings.write_string(&sb, s[2:])

		}
		return strings.to_string(sb)
	}
	return s
}

@(private = "file")
is_integer_token :: proc "contextless" (s: string) -> bool {
	start := 0
	if s[0] == '+' || s[0] == '-' {
		start = 1
		if len(s) == 1 {
			return false
		}
	}

	for i := 0; i < len(s); i += 1 {
		if s[i] == '.' || s[i] == 'e' || s[i] == 'E' {
			return false
		}
	}

	if s[start] == '0' && len(s) > start + 1 {
		c := s[start + 1]
		switch c {
		case 'd', 'x', 'o', 'b':
			return true
		}
	}

	return s[start] >= '0' && s[start] <= '9'
}

@(private = "file")
is_float_token :: proc "contextless" (s: string) -> bool {
	start := 0
	if s[0] == '+' || s[0] == '-' {
		start = 1
		if len(s) == 1 {
			return false
		}
	}

	has_digit := false
	has_dot_or_exp := false

	for i := start; i < len(s); i += 1 {
		c := s[i]
		if c >= '0' && c <= '9' {
			has_digit = true
		} else if c == '.' || c == 'e' || c == 'E' || c == '+' || c == '-' {
			if c == '.' || c == 'e' || c == 'E' {
				has_dot_or_exp = true
			}
		} else {
			return false
		}
	}

	return has_digit && has_dot_or_exp
}

@(private = "file")
read_atom :: proc(r: ^Reader) -> (^Expr, string) {
	start_pos := r.position

	for !is_delimiter(r.ch) {
		next_char(r)
	}

	token := r.input[start_pos:r.position]

	switch strings.to_upper(token) {
	case "T":
		return new_true(), ""
	case "NIL":
		return new_nil(), ""
	}

	cleaned_token := convert_prefixed_token(token)

	if is_integer_token(cleaned_token) {
		i128_num, i128_ok := strconv.parse_i128_maybe_prefixed(cleaned_token)
		if i128_ok {
			if i128_num >= i128(min(i64)) && i128_num <= i128(max(i64)) {
				return new_int(i64(i128_num)), ""
			} else {
				return nil, fmt.tprintf("The integer is too large (i64 overflow): %s", token)
			}
		} else {
			return nil, fmt.tprintf(
				"The integer is too large (i128 overflow) or contains invalid characters: %s",
				token,
			)
		}
	}

	if is_float_token(cleaned_token) {
		f64_num, f64_ok := strconv.parse_f64(cleaned_token)
		if f64_ok {
			return new_float(f64_num), ""
		} else {
			return nil, fmt.tprintf(
				"The float is too large (f64 overflow) or contains invalid characters: %s",
				token,
			)
		}
	}

	return new_symbol(token), ""
}
