// closure_arg_borrow_escape_reject — EXPECTED-NEGATIVE.
//
// A closure that captures a borrow may only be CALLED where it's made.
// Passing it as an argument lets the callee store it (here in r.cb) and run
// it after the borrowed `x` is gone → dangling. Rejected.

package main

type Reg struct {
    cb fun() int
}

fun (r *Reg) On(f fun() int) {
    r.cb = f
}

fun main() int {
    var x int = 1
    var b &int = &x
    var r Reg = new Reg{cb: fun() int { ret 0 }}
    r.On(fun() int { ret *b })   // ERROR: closure captures borrow b, passed as arg
    ret 0
}
