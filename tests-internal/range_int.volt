// Range-over-int: `for i := range N` iterates i from 0 to N-1.
// Mirrors Go 1.22's surface.

package main

import "log"

fun sum10() int {
    var total int = 0
    for i := range 10 {
        total = total + i
    }
    ret total                       // 0+1+...+9 = 45
}

fun countZero() int {
    var c int = 0
    for i := range 0 {
        c = c + 1
        if i < 0 { c = c }          // dead use; loop body should never run
    }
    ret c
}

fun countNeg() int {
    var c int = 0
    for i := range -3 {
        c = c + 1
        if i < 0 { c = c }
    }
    ret c                            // negative N → 0 iters
}

fun useDynamicLimit() int {
    var n int = 5
    var total int = 0
    for i := range n {
        total = total + i
    }
    ret total                       // 0+1+2+3+4 = 10
}

fun blankIndex() int {
    var seen int = 0
    for _ := range 7 {
        seen = seen + 1
    }
    ret seen
}

fun main() int {
    var pass int = 0

    if sum10() == 45            { pass = pass + 1 }
    if countZero() == 0         { pass = pass + 1 }
    if countNeg() == 0          { pass = pass + 1 }
    if useDynamicLimit() == 10  { pass = pass + 1 }
    if blankIndex() == 7        { pass = pass + 1 }

    // Nested
    var nestSum int = 0
    for i := range 3 {
        for j := range 4 {
            nestSum = nestSum + i + j
        }
    }
    // i goes 0..2 (each * 4 from inner loop) + sum of inner j = 0+1+2+3 = 6 per outer
    // total: 3 * 6 (j sums) + 4 * (0+1+2) (i contributions × 4 inner iters)
    //      = 18 + 12 = 30
    if nestSum == 30 { pass = pass + 1 }

    log.Println("pass=%d/6", pass)
    if pass == 6 { ret 42 }
    ret 0
}
