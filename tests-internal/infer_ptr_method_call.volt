// `:=` type inference must recover the concrete pointee type of a
// *T-returning RHS so a later method call on the inferred local
// dispatches correctly. Before the fix the inferred symbol was bound as
// a bare "ptr" (no AstType/Elem): `x.Method()` failed at compile time
// ("cannot call method on ptr"), and the pointer-receiver path mistook
// the pointer var for an owned value and passed &x. This exercises both
// a local *T (mk) and a cross-package one (io.NewStringWriter). Ret 42.
package main

import "io"
import "fmt"

type Counter struct {
	n int
}

fun mk(start int) *Counter {
	ret new Counter {n: start}
}

fun (c *Counter) bump() int {
	c.n = c.n + 1
	ret c.n
}

fun main() int {
	var pass int = 0
	var want int = 3

	// Local *T via := — pointer-receiver method must see the real pointee.
	c := mk(40)
	var a int = c.bump() // 41
	var b int = c.bump() // 42 (mutation through the inferred ptr persists)
	if a == 41 && b == 42 {
		pass = pass + 1
	}

	// Cross-package *T via := — io.StringWriter pointer-receiver methods.
	sink := io.NewStringWriter()
	var _n int = 0
	var _e error = nil
	_n, _e = sink.Write("ab")
	_n, _e = sink.Write("cd")
	if sink.String() == "abcd" {
		pass = pass + 1
	}

	// := result drives the sentinel value too.
	c2 := mk(1)
	if c2.bump() == 2 {
		pass = pass + 1
	}

	fmt.Printf("infer-ptr-method pass=%d/%d\n", pass, want)
	if pass == want {
		ret 42
	}
	ret 1
}
