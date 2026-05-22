// v0.2 test: function with int param + return, called from main.
// Expected: exit code 49.

package main

fun square(x int) int {
    ret x * x
}

fun main() int {
    ret square(7)
}
