// Block-scoped Drop: a struct declared inside a for-body should Drop
// at the end of EACH iteration, not at function end.
//
// Expect 3 lines of "Drop" before main returns.

package main

import "log"

type Tick struct {
    id int
}

fun (t *Tick) Drop() {
    log.Println("Drop")
}

fun main() int {
    for i := 0; i < 3; i++ {
        var _t Tick = new Tick{id: i}
    }
    log.Println("after-loop")
    ret 42
}
