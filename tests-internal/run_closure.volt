package main
import "log"
import "syscall"

fun worker(f fun()) {
    f()
}

fun main() int {
    var c atomic int = new {}
    run worker(fun() {
        c.Add(7)
    })
    syscall.Nanosleep(100000000)   // 100ms
    log.Println("c=%d", c.Read())
    if c.Read() == 7 { ret 42 }
    ret 0
}
