package main
import "log"
import "strings"

fun isComma(b byte) bool { ret b == 44 }
fun isCommaOrSemi(b byte) bool {
	if b == 44 { ret true }
	if b == 59 { ret true }
	ret false
}
fun isSpace(b byte) bool { ret b == 32 }
fun isDigit(b byte) bool {
	if b < 48 { ret false }
	if b > 57 { ret false }
	ret true
}
fun isAllTrue(b byte) bool { ret true }

fun main() int {
	var pass int = 0

	// FieldsFunc — single comma separator.
	var a []string = strings.FieldsFunc("a,b,c", isComma)
	if len(a) == 3 { pass = pass + 1 }
	if a[0] == "a" { pass = pass + 1 }
	if a[1] == "b" { pass = pass + 1 }
	if a[2] == "c" { pass = pass + 1 }

	// FieldsFunc — multiple separators (comma OR semicolon).
	var b []string = strings.FieldsFunc("a,b;c,d;e", isCommaOrSemi)
	if len(b) == 5 { pass = pass + 1 }
	if b[0] == "a" { pass = pass + 1 }
	if b[4] == "e" { pass = pass + 1 }

	// FieldsFunc — runs of separators collapse (no empty pieces).
	var c []string = strings.FieldsFunc("a,,,b,,c", isComma)
	if len(c) == 3 { pass = pass + 1 }
	if c[0] == "a" { pass = pass + 1 }
	if c[1] == "b" { pass = pass + 1 }
	if c[2] == "c" { pass = pass + 1 }

	// FieldsFunc — leading / trailing separators discarded.
	var d []string = strings.FieldsFunc(",,a,b,,", isComma)
	if len(d) == 2 { pass = pass + 1 }
	if d[0] == "a" { pass = pass + 1 }

	// FieldsFunc — empty input.
	var e []string = strings.FieldsFunc("", isComma)
	if len(e) == 0 { pass = pass + 1 }

	// FieldsFunc — all separators (no fields).
	var f []string = strings.FieldsFunc(",,,", isComma)
	if len(f) == 0 { pass = pass + 1 }

	// FieldsFunc — predicate selects spaces (parallels Fields).
	var g []string = strings.FieldsFunc("hello   world  foo", isSpace)
	if len(g) == 3 { pass = pass + 1 }
	if g[0] == "hello" { pass = pass + 1 }
	if g[1] == "world" { pass = pass + 1 }
	if g[2] == "foo" { pass = pass + 1 }

	// FieldsFunc — predicate selects digits → split at digit boundaries.
	var h []string = strings.FieldsFunc("aa1bb22cc3", isDigit)
	if len(h) == 3 { pass = pass + 1 }
	if h[0] == "aa" { pass = pass + 1 }
	if h[1] == "bb" { pass = pass + 1 }
	if h[2] == "cc" { pass = pass + 1 }

	// FieldsFunc — every byte is a separator → no fields.
	var i []string = strings.FieldsFunc("xyz", isAllTrue)
	if len(i) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
