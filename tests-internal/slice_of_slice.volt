package main
import "log"

// Positive test: indexing into a slice-of-slices (e.g. `[][]byte`).
// Previously `s[0][1]` errored with "slice element type unknown —
// was it created via []T{...}?" because the inner-slice result of
// `s[0]` didn't carry its element type through. Codegen now
// propagates the element AST type one level deeper for chained
// indexing (and for IdentExpr / IndexExpr / SelectorExpr sources).

fun main() int {
	var pass int = 0

	var a []byte = new(3) []byte{10, 20, 30}
	var b []byte = new(3) []byte{40, 50, 60}
	var s [][]byte = new(2) [][]byte{a, b}

	if len(s) == 2 { pass = pass + 1 }
	if s[0][0] == 10 { pass = pass + 1 }
	if s[0][1] == 20 { pass = pass + 1 }
	if s[0][2] == 30 { pass = pass + 1 }
	if s[1][0] == 40 { pass = pass + 1 }
	if s[1][1] == 50 { pass = pass + 1 }
	if s[1][2] == 60 { pass = pass + 1 }

	// Indexing through a chained subscript: `[][]int` also works.
	var p []int = new(2) []int{1, 2}
	var q []int = new(2) []int{3, 4}
	var m [][]int = new(2) [][]int{p, q}
	if m[0][0] == 1 { pass = pass + 1 }
	if m[1][1] == 4 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 9 { ret 42 }
	ret 0
}
