// closure_arg_copy_capture — POSITIVE: a closure that captures by VALUE
// (not a borrow) can be passed as an argument freely (the common case).

package main

import "log"

fun apply(f fun() int) int {
    ret f()
}

fun main() int {
    var n int = 20
    var r1 int = apply(fun() int { ret n + n })       // inline copy-capture
    var triple fun() int = fun() int { ret n * 3 }
    var r2 int = apply(triple)                          // var-bound copy-capture
    log.Println("r1=%d r2=%d", r1, r2)
    if r1 != 40 { ret 1 }
    if r2 != 60 { ret 2 }
    ret 42
}
