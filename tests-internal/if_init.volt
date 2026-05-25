// `if init; cond { ... }` — Go-style init clause on if.
// Bindings introduced in the init are scoped to the entire if/else chain.

package main

import "log"

fun maybe() (int, int) { ret 42, 1 }

fun main() int {
    // Multi-var init: v and ok are scoped to the if/else.
    if v, ok := maybe(); ok == 1 {
        log.Println("got v=%d", v)
        if v != 42 { ret 0 }
    } else {
        ret 0
    }

    // Single-var init.
    if n := 100; n > 50 {
        log.Println("n=%d (big)", n)
    } else {
        log.Println("n=%d (small)", n)
        ret 0
    }

    // Init binding stays out of scope after the if/else closes.
    if x := 7; x > 0 {
        log.Println("x=%d", x)
    }
    // x is not visible here — would be a compile error.

    ret 42
}
