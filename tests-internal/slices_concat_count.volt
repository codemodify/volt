// slices.ConcatInts / ConcatStrings / CountInt / CountString smoke.

package main

import "slices"
import "log"

fun main() int {
    var pass int = 0

    // ConcatInts
    var a []int = new(3) []int { 1, 2, 3 }
    var b []int = new(2) []int { 4, 5 }
    var c []int = slices.ConcatInts(a, b)
    if len(c) == 5 { pass = pass + 1 }
    if c[0] == 1 { if c[4] == 5 { pass = pass + 1 } }

    // ConcatInts with empty inputs
    var emp []int = new(0) []int {}
    var c2 []int = slices.ConcatInts(emp, b)
    if len(c2) == 2 { if c2[0] == 4 { pass = pass + 1 } }
    var c3 []int = slices.ConcatInts(a, emp)
    if len(c3) == 3 { if c3[2] == 3 { pass = pass + 1 } }

    // ConcatStrings
    var sa []string = new(2) []string { "hello", "world" }
    var sb []string = new(1) []string { "foo" }
    var sc []string = slices.ConcatStrings(sa, sb)
    if len(sc) == 3 { if sc[0] == "hello" { if sc[2] == "foo" { pass = pass + 1 } } }

    // CountInt
    var d []int = new(7) []int { 1, 2, 3, 2, 1, 2, 4 }
    if slices.CountInt(d, 2) == 3 { pass = pass + 1 }
    if slices.CountInt(d, 1) == 2 { pass = pass + 1 }
    if slices.CountInt(d, 99) == 0 { pass = pass + 1 }
    var ed []int = new(0) []int {}
    if slices.CountInt(ed, 1) == 0 { pass = pass + 1 }

    // CountString
    var ss []string = new(5) []string { "a", "b", "a", "c", "a" }
    if slices.CountString(ss, "a") == 3 { pass = pass + 1 }
    if slices.CountString(ss, "z") == 0 { pass = pass + 1 }

    log.Println("pass=%d/11", pass)
    if pass == 11 { ret 42 }
    ret 0
}
