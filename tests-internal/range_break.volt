package main
import "log"
fun main() int {
    var s []int = new []int{1, 2, 3, 4, 5}
    var sum int = 0
    for _, v := range s {
        if v == 4 { break }
        if v == 2 { continue }
        sum = sum + v
    }
    log.Println("sum=%d", sum)   // 1 + 3 = 4
    if sum == 4 { ret 42 }
    ret 0
}
