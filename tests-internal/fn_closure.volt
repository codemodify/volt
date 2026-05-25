package main
import "log"
fun main() int {
    var n int = 100
    var add fun(int) int = fun(x int) int {
        ret x + n
    }
    var r int = add(5)
    log.Println("result: %d", r)
    if r == 105 { ret 42 }
    ret 0
}
