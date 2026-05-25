// test: locals + multi-arg function + arithmetic + operator precedence.
// 10 + 5 * 2 = 20 (mul binds tighter than add)
// add3(a, b, c) = a + b + c
// 20 + 7 + 15 = 42

package main

fun add3(a int, b int, c int) int {
    ret a + b + c
}

fun main() int {
    var x int = 10
    var y int = 5
    var z int = x + y * 2
    ret add3(z, 7, 15)
}
