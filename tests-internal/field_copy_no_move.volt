// Checker widening: reading a Copy-primitive field doesn't consume
// the parent struct, so multiple Copy-field reads + a movable-field
// read can coexist in the same statement (previously required an
// unpack-via-function workaround).

package main

import "log"

type Pair struct {
    a int
    b int
    c string   // movable — last read still moves the parent
}

fun makePair() Pair {
    ret new Pair {a: 10, b: 20, c: "hi"}
}

fun main() int {
    var pass int = 0

    // Read two Copy fields in sequence — neither moves the parent.
    var p Pair = makePair()
    var aa int = p.a
    var bb int = p.b
    if aa == 10 { pass = pass + 1 }
    if bb == 20 { pass = pass + 1 }

    // Mix: read a Copy field, then read another Copy field, then
    // use the movable field. The movable read is the consuming one.
    var q Pair = makePair()
    var qa int = q.a
    var qb int = q.b
    var qc string = q.c   // movable; moves q
    if qa == 10 { pass = pass + 1 }
    if qb == 20 { pass = pass + 1 }
    if qc == "hi" { pass = pass + 1 }

    // DEMO.2-style direct use of two Copy fields in a single statement
    // through an indexed write — works without the unpack helper now.
    var hashes []int = new(3) []int { 0, 0, 0 }
    var r Pair = makePair()
    hashes[r.a / 5] = r.b   // r.a (Copy) does NOT move r → r.b is still alive
    if hashes[2] == 20 { pass = pass + 1 }   // r.a / 5 = 10/5 = 2

    log.Println("pass=%d/6", pass)
    if pass == 6 { ret 42 }
    ret 0
}
