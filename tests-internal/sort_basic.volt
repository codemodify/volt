// sort smoke — IntsAsc + StringsAsc + AreSorted predicates.
// Mutating helpers return the slice so the caller rebinds across
// the move: `a = sort.IntsAsc(a)`.

package main

import "sort"
import "log"

fun main() int {
    var pass int = 0

    // IntsAsc: 5-element random
    var a []int = new(5) []int { 0, 0, 0, 0, 0 }
    a[0] = 3; a[1] = 1; a[2] = 4; a[3] = 1; a[4] = 5
    a = sort.IntsAsc(a)
    if a[0] == 1 { if a[1] == 1 { if a[2] == 3 { if a[3] == 4 { if a[4] == 5 {
        pass = pass + 1
    } } } } }

    // Already-sorted (median-of-three should still work cleanly)
    var b []int = new(4) []int { 0, 0, 0, 0 }
    b[0] = 1; b[1] = 2; b[2] = 3; b[3] = 4
    b = sort.IntsAsc(b)
    if b[0] == 1 { if b[3] == 4 { pass = pass + 1 } }

    // Reverse-sorted (exercises quicksort worst case → median-3 fix)
    var c []int = new(10) []int { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
    c[0]=10; c[1]=9; c[2]=8; c[3]=7; c[4]=6; c[5]=5; c[6]=4; c[7]=3; c[8]=2; c[9]=1
    c = sort.IntsAsc(c)
    if c[0] == 1 { if c[9] == 10 { pass = pass + 1 } }

    // Larger random — 20 elements with duplicates
    var d []int = new(20) []int { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
    d[0]=15; d[1]=7;  d[2]=3;  d[3]=11; d[4]=15
    d[5]=1;  d[6]=8;  d[7]=2;  d[8]=12; d[9]=4
    d[10]=15; d[11]=6; d[12]=9; d[13]=14; d[14]=5
    d[15]=13; d[16]=10; d[17]=15; d[18]=15; d[19]=0
    d = sort.IntsAsc(d)
    if d[0] == 0 { if d[19] == 15 {
        // Spot-check sortedness inline (avoid moving d into IntsAreSorted).
        var ok bool = true
        for i:=1; i < 20; i++ {
            if d[i] < d[i-1] { ok = false }
        }
        if ok { pass = pass + 1 }
    } }

    // Single element + empty stay correct
    var e []int = new(1) []int { 42 }
    e = sort.IntsAsc(e)
    if e[0] == 42 { pass = pass + 1 }

    var f []int = new(0) []int {}
    f = sort.IntsAsc(f)
    if len(f) == 0 { pass = pass + 1 }

    // StringsAsc
    var s []string = new(5) []string { "", "", "", "", "" }
    s[0] = "delta"; s[1] = "alpha"; s[2] = "bravo"; s[3] = "echo"; s[4] = "charlie"
    s = sort.StringsAsc(s)
    if s[0] == "alpha" { if s[1] == "bravo" { if s[2] == "charlie" {
        if s[3] == "delta" { if s[4] == "echo" {
            pass = pass + 1
        } } } } }

    // String compare: shorter prefix sorts before longer
    var s2 []string = new(3) []string { "", "", "" }
    s2[0] = "abcd"; s2[1] = "abc"; s2[2] = "abcde"
    s2 = sort.StringsAsc(s2)
    if s2[0] == "abc" { if s2[1] == "abcd" { if s2[2] == "abcde" {
        pass = pass + 1
    } } }

    // IntsAreSorted ordering predicates
    var g []int = new(3) []int { 1, 2, 3 }
    if sort.IntsAreSorted(g) { pass = pass + 1 }

    var h []int = new(3) []int { 1, 3, 2 }
    if !sort.IntsAreSorted(h) { pass = pass + 1 }

    log.Println("pass=%d/10", pass)
    if pass == 10 { ret 42 }
    ret 0
}
