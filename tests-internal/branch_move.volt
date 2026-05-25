// branch-joined ownership. Moving in one branch must taint the
// joined state. log.Println(s) after the if should be flagged.

package main

import "log"

fun main() int {
    var s string = "hello"
    if 1 < 2 {
        log.Println(s)  // moves s in the then-branch
    }
    log.Println(s)      // should be rejected: s moved on the path through then
    ret 0
}
