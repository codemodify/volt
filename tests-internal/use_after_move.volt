// Negative test: should be REJECTED by the borrow checker.
// `consume` takes a string by value, so the first call moves `s`.
// Using `s` again is use-after-move.

package main

fun consume(s string) {}

fun main() int {
    var s string = "hello"
    consume(s)
    consume(s)
    ret 0
}
