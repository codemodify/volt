// C8 phase 5: cannot mutate the source variable while a borrow
// (shared or mut) is still active. Rust-style strict freeze rule —
// the borrow's lifetime keeps the source effectively read-only.
package main

fun main() int {
	var x int = 10
	var b &mut int = &mut x
	x = 20  // rejected: x is frozen by the active &mut borrow
	ret *b
}
