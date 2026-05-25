// Negative test: aliasing-XOR-mutation violation.
// `swap` takes two *int — passing the same variable to both is illegal
// (two mutable borrows of x simultaneously).

package main

fun swap(a *int, b *int) {}

fun main() int {
    var x int = 5
    swap(x, x)
    ret 0
}
