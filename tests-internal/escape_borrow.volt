// returning a borrow of a local must be rejected.

package main

fun escape() &int {
    var x int = 5
    ret x   // x is a local; borrow can't escape its scope
}

fun main() int { ret 0 }
