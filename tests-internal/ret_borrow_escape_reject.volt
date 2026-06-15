// ret_borrow_escape_reject — EXPECTED-NEGATIVE.
//
// `ret &x` returns the address of a local — a borrow pointing into this
// call's frame, which would dangle the moment the call returns. Returning a
// borrow is never allowed; return a value (move) or a copy instead.

package main

fun leak() *int {
    var x int = 5
    ret &x          // ERROR: returning a borrow of a local
}

fun main() int {
    var p *int = leak()
    ret *p
}
