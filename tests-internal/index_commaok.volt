// index_commaok — POSITIVE.
//
// `v, ok := a[i]` (comma-ok index) for slices and strings: bounds-checked,
// returns (element, in-bounds), NEVER crashes on OOB / empty / negative.
// Stage 1 of checked indexing (option 5) — additive; bare a[i] is unchanged.

package main

import "log"

fun main() int {
    var a []int = new(0) []int{}
    a = append(a, 10)
    a = append(a, 20)
    a = append(a, 30)

    v, ok := a[1]                     // in bounds
    if !ok || v != 20 { ret 1 }

    w, ok2 := a[99]                   // OOB — no crash, ok=false, zero
    if ok2 || w != 0 { ret 2 }

    n, ok3 := a[0-1]                  // negative — OOB
    if ok3 || n != 0 { ret 3 }

    var e []int = new(0) []int{}
    z, ok4 := e[0]                    // empty slice — zero slot, no crash
    if ok4 || z != 0 { ret 4 }

    var x int = 0
    var okx bool = false
    x, okx = a[2]                     // assign form (pre-declared)
    if !okx || x != 30 { ret 5 }

    var s string = "hi"
    b, oks := s[0]                    // string comma-ok ('h' = 104)
    if !oks || b != 104 { ret 6 }

    log.Println("checked index comma-ok OK")
    ret 42
}
