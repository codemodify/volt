// Phase 2: break + continue in loops.
// Loop 1..50, skip even numbers via continue, break when sum > 100.
// 1+3+5+7+9+11+13+15+17 = 81 (next would push past 100; loop exits).

package main

fun main() int {
    var sum int = 0
    var i int = 0
    for i < 50 {
        i = i + 1
        if i % 2 == 0 {
            continue
        }
        if sum + i > 100 {
            break
        }
        sum = sum + i
    }
    ret sum - 39   // 81 - 39 = 42
}
