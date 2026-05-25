// multi-numeric types (int8, int16, int32, int64).
// Each holds a small value; sum widens to int.
// 10 + 20 + 5 + 7 = 42.

package main

fun main() int {
    var a int8  = 10
    var b int16 = 20
    var c int32 = 5
    var d int64 = 7

    var sum int = a + b + c + d
    ret sum
}
