package main
import "log"
fun main() int {
    var s []int = new []int{10, 20, 30, 40}

    var sum int = 0
    for i, v := range s {
        log.Println("i=%d v=%d", i, v)
        sum = sum + v
    }
    log.Println("sum=%d", sum)   // 100

    // index-only form
    var indices int = 0
    for i := range s {
        indices = indices + i
    }
    log.Println("indices=%d", indices)  // 0+1+2+3 = 6

    if sum == 100 {
        if indices == 6 {
            ret 42
        }
    }
    ret 0
}
