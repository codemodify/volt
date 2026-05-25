// test: if/else, comparisons, returning the bigger value.
// max(7, 12) → 12.

package main

fun max(a int, b int) int {
    if a > b {
        ret a
    } else {
        ret b
    }
}

fun main() int {
    ret max(7, 12)
}
