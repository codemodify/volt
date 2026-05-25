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
    var i int = 0
    for i < 3 {
        var t Tick = new Tick{id: i}
        i = i + 1
    }
    log.Println("after-loop")
    ret 42
}
