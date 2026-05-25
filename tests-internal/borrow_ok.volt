// Positive test: borrowing instead of moving should compile.
// `look` takes &string (shared borrow), so `s` stays alive in main.

package main

fun look(s &string) {}

fun main() int {
    var s string = "hello"
    look(s)
    look(s)
    ret 0
}
