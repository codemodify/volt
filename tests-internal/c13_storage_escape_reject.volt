// C13 storage-escape proof: a closure that captures a borrow cannot
// be STORED into a struct field whose lifetime would outlive the
// borrowed value. Same applies to slice elements and map values
// (verified by sibling rejection paths in emitNewSlice/emitMapSet).
package main

type Holder struct {
	f fun() int
}

fun main() int {
	var x int = 42
	var b &int = &x
	var get fun() int = fun() int { ret *b }
	// REJECTED: storing closure with borrow capture in struct field.
	var h Holder = new Holder{f: get}
	ret h.f()
}
