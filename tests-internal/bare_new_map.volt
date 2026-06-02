package main
import "log"

// Positive test: bare `new map[K]V` (no parens, no braces) now produces
// an empty map — matches the `new chan T` and `new []T` bare forms.
// Previously rejected with "bare `new map[K]V` is not allowed". The
// reject was inconsistent with the other non-struct types — D2 in
// TODO.md called it out. Now `new map[K]V`, `new map[K]V{}`, and
// `new map[K]V(cap)` all produce the same empty-map result.

fun main() int {
	var m map[string]int = new map[string]int
	m["a"] = 1
	m["b"] = 2
	if len(m) != 2 { ret 0 }
	if m["a"] != 1 { ret 0 }
	if m["b"] != 2 { ret 0 }
	log.Println("a=%d b=%d", m["a"], m["b"])
	ret 42
}
