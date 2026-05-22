// v0.4: switch statement (tag form + default).
// classify(7) = 100, classify(3) = 200, classify(99) = 300.
// 100 + 200 + 300 = 600 - 558 = 42.

package main

fun classify(x int) int {
    switch x {
    case 1, 2, 3:
        ret 200
    case 7:
        ret 100
    default:
        ret 300
    }
    ret 0
}

fun main() int {
    var s int = 0
    s = s + classify(7)    // 100
    s = s + classify(3)    // 200
    s = s + classify(99)   // 300
    ret s - 558            // 600 - 558 = 42
}
