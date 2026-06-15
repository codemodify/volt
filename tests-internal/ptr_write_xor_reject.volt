// ptr_write_xor_reject — EXPECTED-NEGATIVE.
//
// `*T` is the exclusive write borrow. Taking `&x` into a `*int` write
// borrow blocks a later shared `&int` peek of the same `x`: shared reads
// and an exclusive write are mutually exclusive (the "many readers OR one
// writer, never both" rule). The checker derives the borrow kind from the
// binding type, so this is rejected at compile time.

package main

fun main() {
	var x int = 5
	var w *int = &x   // exclusive write borrow of x
	var r &int = &x   // ERROR: x already has a *T write borrow active
	*w = *r
}
