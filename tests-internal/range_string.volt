package main
import "log"
fun main() int {
    var s string = "ABCDE"
    var sum int = 0
    for i, c := range s {
        log.Println("i=%d c=%d", i, c)
        sum = sum + i
    }
    // i values 0..4 → sum = 10
    if sum == 10 { ret 42 }
    ret 0
}
