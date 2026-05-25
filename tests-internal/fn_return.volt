package main
import "log"

fun make_adder(n int) fun(int) int {
    ret fun(x int) int { ret x + n }
}

fun main() int {
    var add5 fun(int) int = make_adder(5)
    var r int = add5(10)
    log.Println("r=%d", r)
    if r == 15 { ret 42 }
    ret 0
}
