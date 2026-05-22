// v0.4 Phase 2: field assignment + method that mutates.
// bump() takes *Counter and increments .value.
// After 3 bumps starting at 39: 42.

package main

type Counter struct {
    value int
}

fun (c *Counter) bump() {
    c.value = c.value + 1
}

fun main() int {
    var c Counter = new Counter{value: 39}
    c.bump()
    c.bump()
    c.bump()
    ret c.value
}
