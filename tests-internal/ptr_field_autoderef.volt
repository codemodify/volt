package main

// Positive test: field access on a ptr-to-struct value (from a
// call result or a slice/map element) now auto-derefs. The
// `pointeeStructName(expr)` helper recovers the *T return/element
// type from the source expression; emitFieldExpr loads the struct
// from the ptr before resolving the field. Same pattern as method
// dispatch's FEAT.1/2/3 spills, but for plain field reads.

type Box struct {
	x int
}

fun make() *Box {
	ret new Box{x: 42}
}

fun main() int {
	// Field on a call result of *T.
	if make().x != 42 { ret 1 }

	// Field on a slice element of *T (the slice-literal also gets
	// the new maybeBoxForPointer call to heap-allocate elements).
	var s []*Box = new(2) []*Box{new Box{x: 7}, new Box{x: 35}}
	if s[0].x + s[1].x != 42 { ret 2 }

	ret 42
}
