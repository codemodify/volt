// volt:noformat — spec file; hand-aligned.
// =====================================================================
// move.volt — handing a value over (it becomes unusable after you pass it)
// =====================================================================
// Passing an owned value `T` into a function whose parameter is also `T`
// MOVES it: the callee takes ownership, and the caller's variable is
// invalidated. Using the caller's variable afterward is a compile error
// (see commented-out line below — uncomment to see the diagnostic).
//
// To keep ownership in the caller's scope, call a function whose
// parameter is `&T` (read access) or `*T` (write access) — at the
// call site the syntax is still bare `b`, no `&` or `*` operator.
//
//   volt run docs/design/move.volt

package main

import "log"

// Buffer owns a string (a movable field), so Buffer is a MOVE type:
// passing it by value transfers ownership. (A struct of only Copy fields
// — see Point below — would instead COPY.)
type Buffer struct {
    name string
    size int
}

// consumes takes ownership of b. b is freed at the end of `consumes`.
fun consumes(b Buffer) {
    if b.size > 0 {
        log.Println("consumes: saw %s", b.name)
    }
}

// peek has read access to b; b stays alive at the caller.
fun peek(b &Buffer) {
    log.Println("peek: saw a buffer")
}

// =====================================================================
// COPY structs — the exception to "composites move"
// =====================================================================
// A struct whose fields are ALL Copy (primitives or other all-Copy
// structs) AND that has no Drop method is itself COPY: passing it by
// value copies it, so the source stays usable. No heap backing means the
// copy is free and safe — the move rules simply don't apply.

type Point struct {
    x int
    y int
}

fun area(p Point) int {
    ret p.x * p.y
}

fun main() {
    var b1 Buffer = new Buffer{name: "scratch", size: 8}
    consumes(b1)
    // log.Println(b1.size)   // ← would be: use-after-move compile error
                              //   (Buffer owns a string, so it MOVED)

    var b2 Buffer = new Buffer{name: "shared", size: 16}
    peek(b2)
    peek(b2)                  // still alive: read access doesn't consume

    // Point is all-Copy, so passing it by value does NOT move it:
    var p Point = new Point{x: 4, y: 5}
    log.Println("area=%d", area(p))
    log.Println("area=%d", area(p))   // p still usable — Point is COPY

    log.Println("move ok")
}
