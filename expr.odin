package main

import "core:fmt"
import "core:strings"

LispProc :: #type proc(args: [dynamic]^Exp) -> (^Exp, string)

ExpSymbol :: struct {
	sym: string,
}

ExpNumber :: struct {
	num: i64,
}

ExpFloat :: struct {
	flo: f64,
}

ExpString :: struct {
	str: string,
}

ExpTrue :: struct {
	val: int,
}

ExpNil :: struct {
	val: int,
}

ExpList :: struct {
	list: [dynamic]^Exp,
}

ExpCons :: struct {
	car: ^Exp,
	cdr: ^Exp,
}

ExpProc :: struct {
	pro: LispProc,
}

ExpLambda :: struct {
	params:  [dynamic]string,
	body:    ^Exp,
	closure: ^Env,
}

Exp :: union {
	ExpSymbol,
	ExpNumber,
	ExpFloat,
	ExpString,
	ExpTrue,
	ExpNil,
	ExpList,
	ExpCons,
	ExpProc,
	ExpLambda,
}

List :: [dynamic]string

exp_to_string :: proc(exp: ^Exp) -> string {
	switch e in exp {
	case ExpSymbol:
		return e.sym
	case ExpNumber:
		return fmt.tprintf("%d", e.num)
	case ExpFloat:
		return fmt.tprintf("%g", e.flo)
	case ExpString:
		return fmt.tprintf("\"%s\"", e.str)
	case ExpList:
		sb := strings.builder_make()
		strings.write_string(&sb, "(")
		for item, i in e.list {
			if i > 0 {
				strings.write_string(&sb, " ")
			}
			item_str := exp_to_string(item)
			strings.write_string(&sb, item_str)
		}
		strings.write_string(&sb, ")")
		return strings.to_string(sb)
	case ExpCons:
		sb: strings.Builder
		strings.builder_init(&sb)
		strings.write_string(&sb, "(")

		current := exp
		main_loop: for {
			c := current.(ExpCons) // 現在のConsセル

			// car（要素）を出力
			strings.write_string(&sb, exp_to_string(c.car))

			// cdr（次の要素）の型をチェック
			#partial switch next in c.cdr {
			case ExpNil:
				// 次が NIL ならリストの終わり
				// strings.write_string(&sb, ")")
				// return strings.to_string(sb)
				break main_loop
			case ExpList:
				// 💡 あなたの `cons` が作った `ExpList`（空配列）がここに流れてきます。
				// 要素数が 0 の場合は、NIL と同じ扱いにしてドットを書かずに終了します。
				if len(next.list) == 0 {
					break main_loop
				}
				// 💡 空配列ではない（要素がある）場合は、通常のドット対としてここで処理をします
				strings.write_string(&sb, " . ")
				strings.write_string(&sb, exp_to_string(c.cdr))
				break main_loop
			case ExpCons:
				// 次も Cons セルなら、スペースを空けてループを継続（ドットは書かない！）
				strings.write_string(&sb, " ")
				current = c.cdr
			case:
				// 次が NIL でも Cons でもなければ「本物のドット対」なので . を書いて終了
				strings.write_string(&sb, " . ")
				strings.write_string(&sb, exp_to_string(c.cdr))
				// strings.write_string(&sb, ")")
				// return strings.to_string(sb)
				break main_loop
			}
		}
		strings.write_string(&sb, ")")
		return strings.to_string(sb)

	// return fmt.tprintf("(%s . %s)", exp_to_string(e.car), exp_to_string(e.cdr))
	case ExpTrue:
		return "T"
	case ExpNil:
		return "NIL"
	case ExpProc:
		return "<proc>"
	case ExpLambda:
		return "<lambda>"
	}

	unimplemented("Reached the end of exp_to_string()")
}
