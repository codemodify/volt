// v0.4 Phase 2: methods on a struct, both value-receiver-like and borrow.
// Counter.read takes &Counter; .total takes &Counter and uses .value + .bump.
// 15 + 27 = 42.

package main

type Counter struct {
    value int
    bump  int
}

fun (c &Counter) read() int {
    ret c.value
}

fun (c &Counter) total() int {
    ret c.value + c.bump
}

fun main() int {
    var c Counter = new Counter{value: 15, bump: 27}
    ret c.total()
}
