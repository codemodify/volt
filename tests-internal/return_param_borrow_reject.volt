// return_param_borrow_reject — EXPECTED-NEGATIVE.
//
// "Values own, borrows visit": a borrow never leaves the call that holds it
// — not even a borrow of a parameter. The caller's value might die before
// the returned borrow is used, so the rule is simply "borrows don't escape".
// To hand something back, return a value (move) or a copy.

package main

fun identity(x &int) &int {
    ret x          // ERROR: a borrow (even of a parameter) can't outlive its call
}

fun main() int {
    var n int = 42
    var r &int = identity(n)
    ret r
}
