// recursive_free — POSITIVE. #5: a value-struct's heap FIELD payloads
// (string/slice/map buffers, recursing nested structs) are reclaimed at
// scope end — gated on the checker's move-state (no double-free on
// copy/move) and on Drop-free structs (no Drop-ordering hazard). Covers the
// adversarial no-double-free / no-UAF cases + exercises the free path.

package main

import "log"

type Rec struct {
    name string
    tags []int
}

fun copyCase() int {
    var r Rec = new Rec{name: "" + "hi", tags: new(0) []int{}}
    r.tags = append(r.tags, 1)
    var r2 Rec = r                    // r moves → only r2 frees (no double-free)
    ret len(r2.name) + len(r2.tags)
}

fun extractCase() string {
    var r Rec = new Rec{name: "" + "payload", tags: new(0) []int{}}
    var s string = r.name            // field-extract → r moves, free suppressed
    ret s                            // returned string stays valid (no UAF)
}

fun storeCase() int {
    var xs []Rec = new(0) []Rec{}
    var r Rec = new Rec{name: "" + "in-slice", tags: new(0) []int{}}
    xs = append(xs, r)               // r moves into xs (no double-free)
    ret len(xs[0].name)
}

fun makeOne(i int) int {
    var r Rec = new Rec{name: "" + "loop-payload", tags: new(0) []int{}}
    r.tags = append(r.tags, i)
    ret len(r.name)                  // r's payloads freed at return (the leak fix)
}

fun main() int {
    if copyCase() != 3 { ret 1 }
    if extractCase() != "payload" { ret 2 }
    if storeCase() != 8 { ret 3 }
    var i int = 0
    var acc int = 0
    for i = 0; i < 100000; i++ {
        acc = acc + makeOne(i)
    }
    if acc < 0 { ret 4 }
    log.Println("recursive free: copy/extract/store/loop OK")
    ret 42
}
