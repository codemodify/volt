// slices package smoke — Contains / Index / Reverse / Sum / Min / Max.

package main

import "slices"
import "log"

fun main() int {
    var pass int = 0

    var a []int = new(5) []int { 3, 1, 4, 1, 5 }

    // ContainsInt / IndexInt
    if slices.ContainsInt(a, 4)   { pass = pass + 1 }
    if !slices.ContainsInt(a, 99) { pass = pass + 1 }
    if slices.IndexInt(a, 4) == 2 { pass = pass + 1 }
    if slices.IndexInt(a, 1) == 1 { pass = pass + 1 }   // first occurrence
    if slices.IndexInt(a, 99) == -1 { pass = pass + 1 }

    // SumInts / MinInts / MaxInts (don't move a yet — they take a borrow-like read)
    if slices.SumInts(a) == 14 { pass = pass + 1 }
    if slices.MinInts(a) == 1  { pass = pass + 1 }
    if slices.MaxInts(a) == 5  { pass = pass + 1 }

    // Empty slice cases
    var e []int = new(0) []int {}
    if !slices.ContainsInt(e, 0) { pass = pass + 1 }
    if slices.IndexInt(e, 0) == -1 { pass = pass + 1 }
    if slices.SumInts(e) == 0 { pass = pass + 1 }
    if slices.MinInts(e) == 0 { pass = pass + 1 }   // empty → 0
    if slices.MaxInts(e) == 0 { pass = pass + 1 }

    // ReverseInts (move + rebind)
    var r []int = new(5) []int { 1, 2, 3, 4, 5 }
    r = slices.ReverseInts(r)
    if r[0] == 5 { if r[4] == 1 { pass = pass + 1 } }
    // Odd-length reverse leaves middle in place
    if r[2] == 3 { pass = pass + 1 }

    // Even-length reverse
    var r2 []int = new(4) []int { 10, 20, 30, 40 }
    r2 = slices.ReverseInts(r2)
    if r2[0] == 40 { if r2[3] == 10 { pass = pass + 1 } }

    // String variants
    var s []string = new(3) []string { "alpha", "bravo", "charlie" }
    if slices.ContainsString(s, "bravo")    { pass = pass + 1 }
    if !slices.ContainsString(s, "delta")   { pass = pass + 1 }
    if slices.IndexString(s, "charlie") == 2 { pass = pass + 1 }
    if slices.IndexString(s, "delta") == -1  { pass = pass + 1 }

    var sr []string = new(3) []string { "first", "second", "third" }
    sr = slices.ReverseStrings(sr)
    if sr[0] == "third"  { pass = pass + 1 }
    if sr[2] == "first"  { pass = pass + 1 }

    log.Println("pass=%d/22", pass)
    if pass == 22 { ret 42 }
    ret 0
}
