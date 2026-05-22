// v0.2 test: recursive fibonacci.
// fib(10) = 55.

package main

fun fib(n int) int {
    if n < 2 {
        ret n
    }
    ret fib(n - 1) + fib(n - 2)
}

fun main() int {
    ret fib(10)
}
