// select with default.
// No producer feeds ch, so the default branch runs immediately.
// Returns 42.

package main

fun main() int {
    var ch chan int = new(1) chan int
    var got int = 100
    select {
    case v := read(ch):
        got = v
    default:
        got = 42
    }
    ret got
}
