package main

// Positive test: nested field assignments through ptr-to-struct
// chains. `o.i.x = 42` and `w.o.i.x = 42` both work — the LHS
// SelectorExpr is recognized as a nested chain, the container
// pointer is computed via emitExpr (auto-deref through any
// intermediate *T fields), and the final field is stored via GEP.

type Inner struct {
	x int
}

type Outer struct {
	i *Inner
}

type Wrap struct {
	o *Outer
}

fun main() int {
	// One-level nesting.
	var o Outer = new Outer{i: new Inner{x: 0}}
	o.i.x = 7
	if o.i.x != 7 { ret 1 }

	// Two-level nesting.
	var w Wrap = new Wrap{o: new Outer{i: new Inner{x: 0}}}
	w.o.i.x = 35
	if w.o.i.x != 35 { ret 2 }

	ret 42
}
