// math integer helpers smoke.

package main

import "math"
import "log"

fun main() int {
    var pass int = 0

    // AbsInt
    if math.AbsInt(5)  == 5 { pass = pass + 1 }
    if math.AbsInt(-5) == 5 { pass = pass + 1 }
    if math.AbsInt(0)  == 0 { pass = pass + 1 }
    // MinInt overflow contract: AbsInt of the smallest representable
    // signed 64-bit int returns itself (since +9223372036854775808
    // can't be represented). Literal value to dodge cross-package
    // const access (not yet supported in codegen).
    var minInt int = -9223372036854775807 - 1
    if math.AbsInt(minInt) == minInt { pass = pass + 1 }

    // MinInt2 / MaxInt2
    if math.MinInt2(3, 7) == 3 { pass = pass + 1 }
    if math.MinInt2(-1, 0) == -1 { pass = pass + 1 }
    if math.MaxInt2(3, 7) == 7 { pass = pass + 1 }
    if math.MaxInt2(-1, 0) == 0 { pass = pass + 1 }

    // ClampInt
    if math.ClampInt(5, 1, 10)  == 5  { pass = pass + 1 }
    if math.ClampInt(-1, 1, 10) == 1  { pass = pass + 1 }
    if math.ClampInt(99, 1, 10) == 10 { pass = pass + 1 }

    // PowInt
    if math.PowInt(2, 0)  == 1     { pass = pass + 1 }
    if math.PowInt(2, 1)  == 2     { pass = pass + 1 }
    if math.PowInt(2, 10) == 1024  { pass = pass + 1 }
    if math.PowInt(3, 5)  == 243   { pass = pass + 1 }
    if math.PowInt(10, 6) == 1000000 { pass = pass + 1 }
    if math.PowInt(5, -1) == 1     { pass = pass + 1 }   // negative exp clamps to 0 → 1

    // IsqrtFloor
    if math.IsqrtFloor(0)   == 0 { pass = pass + 1 }
    if math.IsqrtFloor(1)   == 1 { pass = pass + 1 }
    if math.IsqrtFloor(4)   == 2 { pass = pass + 1 }
    if math.IsqrtFloor(9)   == 3 { pass = pass + 1 }
    if math.IsqrtFloor(8)   == 2 { pass = pass + 1 }   // floor below 3
    if math.IsqrtFloor(99)  == 9 { pass = pass + 1 }   // floor below 10
    if math.IsqrtFloor(100) == 10 { pass = pass + 1 }
    if math.IsqrtFloor(-7)  == 0 { pass = pass + 1 }   // negative → 0

    // GcdInt
    if math.GcdInt(12, 8)   == 4  { pass = pass + 1 }
    if math.GcdInt(17, 5)   == 1  { pass = pass + 1 }   // coprime
    if math.GcdInt(0, 9)    == 9  { pass = pass + 1 }
    if math.GcdInt(0, 0)    == 0  { pass = pass + 1 }
    if math.GcdInt(-12, 8)  == 4  { pass = pass + 1 }   // normalize negatives

    // ModInt — always-positive
    if math.ModInt(7, 3)    == 1  { pass = pass + 1 }
    if math.ModInt(-1, 3)   == 2  { pass = pass + 1 }   // would be -1 with %, here normalized
    if math.ModInt(-7, 3)   == 2  { pass = pass + 1 }   // -7 % 3 = -1; +3 → 2
    if math.ModInt(0, 5)    == 0  { pass = pass + 1 }
    if math.ModInt(5, 0)    == 0  { pass = pass + 1 }   // m <= 0 → 0

    log.Println("pass=%d/35", pass)
    if pass == 35 { ret 42 }
    ret 0
}
