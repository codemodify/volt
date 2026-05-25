// =====================================================================
// move.volt — move semantics
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

type Buffer struct {
    size int
}

// consumes takes ownership of b. b is freed at the end of `consumes`.
fun consumes(b Buffer) {
    if b.size > 0 {
        log.Println("consumes: saw a buffer")
    }
}

// peek has read access to b; b stays alive at the caller.
fun peek(b &Buffer) {
    log.Println("peek: saw a buffer")
}

fun main() {
    var b1 Buffer = new Buffer{size: 8}
    consumes(b1)
    // log.Println(b1.size)   // ← would be: use-after-move compile error

    var b2 Buffer = new Buffer{size: 16}
    peek(b2)
    peek(b2)                  // still alive: read access doesn't consume

    log.Println("move ok")
}
