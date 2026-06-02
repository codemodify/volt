package main

// Positive test: method dispatch on a method-call result where the
// inner method's receiver is itself a complex expression (slice
// index, field access, call result, etc.). Required
// `spillCallResultAsLocal` to extract the receiver type via
// `pointeeStructName(fn.X)` when fn.X isn't an IdentExpr.

type Box struct {
	x int
}

fun (b *Box) Get() int {
	ret b.x
}

fun (b *Box) Doubled() *Box {
	ret new Box{x: b.x * 2}
}

fun main() int {
	// Inner receiver is a slice index.
	var s []*Box = new(2) []*Box{new Box{x: 21}, new Box{x: 0}}
	if s[0].Doubled().Get() != 42 { ret 1 }

	ret 42
}
