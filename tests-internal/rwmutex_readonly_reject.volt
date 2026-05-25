// rwmutex.LockRead() yields a read-only guard. Writing through it
// (field assign or rebinding) must be rejected at compile time.
//
// This file is a NEGATIVE test: it should fail to compile with a
// "read-only guard" error. The internal Go test suite runs the
// compiler on this and asserts the error.

package main

type S struct {
    n int
}

fun main() int {
    var r rwmutex S = new {n: 0}
    var v S = r.LockRead()
    v.n = 1                       // expected: compile error — read-only guard
    ret 0
}
