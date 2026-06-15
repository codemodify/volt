// move_on_insert_reject — EXPECTED-NEGATIVE.
//
// move-on-insert: appending a movable value hands it INTO the slice, so it's
// consumed — using it afterwards would alias the slice's storage. Rejected.

package main

import "log"

type Note struct {
    text string
}

fun main() int {
    var xs []Note = new(0) []Note{}
    var n Note = new Note{text: "hi"}
    xs = append(xs, n)         // n moves into xs
    log.Println("%s", n.text)  // ERROR: use of moved value n
    ret 42
}
