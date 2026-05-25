// Float literals, arithmetic, and comparison.
//   - 32 and 64 bit literals (with `_` separators)
//   - cross-width arithmetic (auto-widen)
//   - int promotes to float in mixed expressions
//   - comparison uses fcmp

package main

fun main() int {
    var a float32 = 3.14
    var b float64 = 2.0
    var c float64 = a + b           // a auto-widens to double, c = 5.14
    var d float64 = c * 2           // int literal promotes to 2.0
    if d > 10 {                     // d == 10.28
        if a < 4 {
            ret 42
        }
    }
    ret 0
}
