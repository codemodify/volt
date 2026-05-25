package main
import "log"
fun main() int {
    var sum int = 0
    for i := 0; i < 5; i++ {
        sum = sum + i
    }
    log.Println("sum=%d", sum)  // 0+1+2+3+4 = 10

    var j int = 10
    j--
    j--
    log.Println("j=%d", j)      // 8

    if sum == 10 {
        if j == 8 {
            ret 42
        }
    }
    ret 0
}
