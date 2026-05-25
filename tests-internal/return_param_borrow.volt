// returning a borrow of a parameter IS allowed —
// the caller's value outlives this function.

package main

fun identity(x &int) &int {
    ret x
}

fun main() int {
    var n int = 42
    var r &int = identity(n)
    ret r   // auto-deref via &int return
}
