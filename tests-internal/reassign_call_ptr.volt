// COMPILER.reassign-call-ptr: reassigning a `*T` variable from a call that
// returns `*T` (`b = mk(...)`) must REBIND the pointer. Previously this
// failed clang with a value/ptr type mismatch (the assign path tried to
// write the pointer through to the pointee). var-decl / `:=` already worked;
// this covers the AssignStmt path.
package main

type Box struct {
	n int
}

fun mk(v int) *Box { ret new Box{n: v} }

fun main() int {
	var b *Box = mk(1)
	b = mk(20) // rebind from a *T-returning call (the fixed case)
	b = mk(42) // rebind again
	ret b.n
}
