// Multiple `_` blanks on a single `:=` (or `=`) multi-bind LHS must be
// allowed — each `_` discards its field. Before the fix the second `_`
// collided on the `%_.addr` alloca and tripped bindLocal's same-scope
// redeclare guard ("local variable \"_\" redeclared"), forcing callers
// into verbose named-throwaway temporaries. Covers a free function and
// a method (the common `out, _, _ := cmd.Run()` shape). Ret 42.
package main

import "fmt"

type Box struct {
	v int
}

fun (b *Box) triple() (int, int, int) {
	ret b.v, b.v * 2, b.v * 3
}

fun three() (string, int, int) {
	ret "ok", 7, 9
}

fun main() int {
	var pass int = 0
	var want int = 3

	// Free function, two trailing blanks.
	a, _, _ := three()
	if a == "ok" {
		pass = pass + 1
	}

	// Method on a := -inferred *T, leading + trailing blanks.
	bx := new Box {v: 5}
	_, mid, _ := bx.triple()
	if mid == 10 {
		pass = pass + 1
	}

	// Blanks in a plain `=` multi-assign too.
	var keep int = 0
	_, keep, _ = bx.triple()
	if keep == 10 {
		pass = pass + 1
	}

	fmt.Printf("multi-blank pass=%d/%d\n", pass, want)
	if pass == want {
		ret 42
	}
	ret 1
}
