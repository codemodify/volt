// C8 phase 5: cannot mutate the source variable while a borrow
// (shared read `&T` or exclusive write `*T`) is still active.
// Rust-style strict freeze rule — the borrow's lifetime keeps the
// source effectively read-only.
package main

fun main() int {
	var x int = 10
	var b *int = &x
	x = 20  // rejected: x is frozen by the active write borrow (*int)
	ret *b
}
