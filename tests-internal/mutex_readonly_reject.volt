// mutex.LockRead() yields a read-only guard. Writing through it
// must fail at compile time.
//
// NEGATIVE test: must NOT compile.

package main

type S struct {
    n int
}

fun main() int {
    var m mutex S = new{n: 0}
    var v S = m.LockRead()
    v.n = 1                       // expected: compile error — read-only guard
    ret 0
}
