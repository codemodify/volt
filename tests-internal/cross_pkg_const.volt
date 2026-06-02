// Cross-package const access: math.MaxInt / math.MinInt etc. resolve
// through the codegen extConsts table.

package main

import "math"
import "log"

fun main() int {
    var pass int = 0

    // Direct read of imported const.
    if math.MaxInt == 9223372036854775807 { pass = pass + 1 }
    var maxI int = math.MaxInt
    if maxI == 9223372036854775807 { pass = pass + 1 }

    // Two consts in one expression.
    if math.MaxInt + math.MinInt == -1 { pass = pass + 1 }   // -MaxInt-1 + MaxInt = -1

    // Use as a function arg.
    if math.AbsInt(math.MinInt) == math.MinInt { pass = pass + 1 }   // overflow contract

    // Comparison + arithmetic.
    if math.MaxInt - 1 == 9223372036854775806 { pass = pass + 1 }

    log.Println("pass=%d/5", pass)
    if pass == 5 { ret 42 }
    ret 0
}
