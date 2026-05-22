// v0.3 test: borrow types and bare-name inference.
// Caller passes `n` bare; compiler takes its address because the
// callee expects &int. Auto-deref happens inside read.
// 3 * 14 = 42.

package main

fun read(n &int) int {
    ret n
}

fun triple(n &int) int {
    ret n + n + n
}

fun main() int {
    var x int = 14
    var r int = triple(x)
    ret r
}
