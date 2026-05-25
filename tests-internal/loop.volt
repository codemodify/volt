// test: for loop with init/cond/post + assignment.
// Sums 1..10 = 55.

package main

fun sumTo(n int) int {
    var total int = 0
    var i int = 1
    for i <= n {
        total = total + i
        i = i + 1
    }
    ret total
}

fun main() int {
    ret sumTo(10)
}
