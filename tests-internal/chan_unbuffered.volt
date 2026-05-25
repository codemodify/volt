package main
import "log"

fun sender(ch chan int, done chan int) {
    log.Println("sender: before write")
    write(ch, 42)              // unbuffered: blocks until receiver reads
    log.Println("sender: after write (handoff confirmed)")
    write(done, 1)
}

fun main() int {
    var ch chan int = new()          // default cap=0 (unbuffered)
    var done chan int = new()        // also cap=0
    run sender(ch, done)
    log.Println("main: about to read")
    var v int = read(ch)
    log.Println("main: got v=%d", v)
    read(done)
    if v == 42 { ret 42 }
    ret 0
}
