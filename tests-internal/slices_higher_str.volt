// slices higher-order helpers for []string.

package main

import "slices"
import "strings"
import "log"

fun isLong(s string) bool { ret len(s) >= 5 }
fun isEmpty(s string) bool { ret len(s) == 0 }
fun startsWithA(s string) bool { ret strings.HasPrefix(s, "a") }
fun upper(s string) string { ret strings.ToUpper(s) }
fun lower(s string) string { ret strings.ToLower(s) }
fun trimSpace(s string) string { ret strings.TrimSpace(s) }

fun main() int {
    var pass int = 0

    var a []string = new(5) []string { "alpha", "bravo", "charlie", "delta", "echo" }

    // FilterStrings
    var longs []string = slices.FilterStrings(a, isLong)
    if len(longs) == 4 { pass = pass + 1 }       // bravo, charlie, delta, alpha → wait alpha is 5
    // alpha (5), bravo (5), charlie (7), delta (5), echo (4) → 4 long
    if longs[0] == "alpha" { if longs[2] == "charlie" { pass = pass + 1 } }

    var starts []string = slices.FilterStrings(a, startsWithA)
    if len(starts) == 1 { if starts[0] == "alpha" { pass = pass + 1 } }

    // Filter with no survivors
    var none []string = slices.FilterStrings(a, isEmpty)
    if len(none) == 0 { pass = pass + 1 }

    // MapStrings: uppercase
    var upper []string = slices.MapStrings(a, upper)
    if len(upper) == 5 { pass = pass + 1 }
    if upper[0] == "ALPHA" { if upper[4] == "ECHO" { pass = pass + 1 } }

    // MapStrings: lowercase round-trip
    var down []string = slices.MapStrings(upper, lower)
    if down[0] == "alpha" { if down[4] == "echo" { pass = pass + 1 } }

    // MapStrings: trim
    var padded []string = new(3) []string { "  hi  ", "\t\nbye\r\n", "no-pad" }
    var trimmed []string = slices.MapStrings(padded, trimSpace)
    if trimmed[0] == "hi"     { pass = pass + 1 }
    if trimmed[1] == "bye"    { pass = pass + 1 }
    if trimmed[2] == "no-pad" { pass = pass + 1 }

    // AnyString
    if slices.AnyString(a, isLong)         { pass = pass + 1 }
    if !slices.AnyString(a, isEmpty)       { pass = pass + 1 }
    var empty []string = new(0) []string {}
    if !slices.AnyString(empty, isLong)    { pass = pass + 1 }

    // AllString
    if slices.AllString(a, isLong) {
        // alpha=5, bravo=5, charlie=7, delta=5, echo=4 → echo fails ≥5
        pass = pass + 0
    }
    if !slices.AllString(a, isLong)        { pass = pass + 1 }    // echo (4) breaks the streak
    if slices.AllString(empty, isLong)     { pass = pass + 1 }    // vacuous truth

    log.Println("pass=%d/15", pass)
    if pass == 15 { ret 42 }
    ret 0
}
