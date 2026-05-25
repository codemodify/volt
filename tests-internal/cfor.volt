// test: classic C-style for loop with `:=` short var decl.
// Sums 1..10 = 55.

package main

fun main() int {
    var total int = 0
    for i := 1; i <= 10; i = i + 1 {
        total = total + i
    }
    ret total
}
