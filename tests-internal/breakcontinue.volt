// break + continue in loops.
// Sum odd i in 1..15 via continue, then break out.
// 1+3+5+7+9+11+13+15 = 64. Subtract 22 = 42.

package main

fun main() int {
    var sum int = 0
    var i int = 0
    for i < 100 {
        i = i + 1
        if i > 15 {
            break
        }
        if i % 2 == 0 {
            continue
        }
        sum = sum + i
    }
    ret sum - 22
}
