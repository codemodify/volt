// pass struct by borrow (&T), access field inside callee.
// User of `Counter` shouldn't have to copy it just to read.
// 5 * 3 + 27 = 42.

package main

type Counter struct {
    value int
    bump  int
}

fun sum(c &Counter) int {
    ret c.value + c.bump
}

fun main() int {
    var c Counter = new Counter{value: 15, bump: 27}
    ret sum(c)
}
