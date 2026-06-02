// slices higher-order helpers: Filter / Map / Any / All.

package main

import "slices"
import "log"

fun isEven(x int) bool { ret (x & 1) == 0 }
fun isOdd(x int) bool  { ret (x & 1) != 0 }
fun isPositive(x int) bool { ret x > 0 }
fun isNegative(x int) bool { ret x < 0 }
fun square(x int) int { ret x * x }
fun double(x int) int { ret x * 2 }

fun main() int {
    var pass int = 0

    var a []int = new(6) []int { 1, 2, 3, 4, 5, 6 }

    // FilterInts
    var evens []int = slices.FilterInts(a, isEven)
    if len(evens) == 3 { pass = pass + 1 }
    if evens[0] == 2 { if evens[1] == 4 { if evens[2] == 6 { pass = pass + 1 } } }

    var odds []int = slices.FilterInts(a, isOdd)
    if len(odds) == 3 { pass = pass + 1 }
    if odds[0] == 1 { if odds[2] == 5 { pass = pass + 1 } }

    // Filter with no survivors → empty slice
    var none []int = slices.FilterInts(a, isNegative)
    if len(none) == 0 { pass = pass + 1 }

    // Filter on empty input
    var emptyIn []int = new(0) []int {}
    var emptyOut []int = slices.FilterInts(emptyIn, isPositive)
    if len(emptyOut) == 0 { pass = pass + 1 }

    // MapInts
    var squared []int = slices.MapInts(a, square)
    if len(squared) == 6 { pass = pass + 1 }
    if squared[0] == 1 { if squared[2] == 9 { if squared[5] == 36 { pass = pass + 1 } } }

    var doubled []int = slices.MapInts(a, double)
    if doubled[0] == 2 { if doubled[5] == 12 { pass = pass + 1 } }

    // AnyInt
    if slices.AnyInt(a, isEven)        { pass = pass + 1 }
    if !slices.AnyInt(a, isNegative)   { pass = pass + 1 }
    var empty []int = new(0) []int {}
    if !slices.AnyInt(empty, isEven)   { pass = pass + 1 }   // empty → no element satisfies

    // AllInt
    if slices.AllInt(a, isPositive)    { pass = pass + 1 }
    if !slices.AllInt(a, isEven)       { pass = pass + 1 }   // 1, 3, 5 violate
    if slices.AllInt(empty, isPositive) { pass = pass + 1 }   // vacuous truth

    log.Println("pass=%d/15", pass)
    if pass == 15 { ret 42 }
    ret 0
}
