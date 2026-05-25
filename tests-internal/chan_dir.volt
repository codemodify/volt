package main
import "log"

fun producer(out chan write int) {
    for i := 0; i < 5; i++ {
        write(out, i)
    }
    close(out)
}

fun consumer(in chan read int, done chan write int) {
    var sum int = 0
    for {
        v, ok := read(in)
        if !ok { break }
        sum = sum + v
    }
    write(done, sum)
}

fun main() int {
    var ch chan int = new(2)         // unrestricted handle (read + write)
    var done chan int = new(1)       // unrestricted handle (read + write)
    run producer(ch)                  // narrows to chan write int
    run consumer(ch, done)            // narrows to chan read + chan write
    var total int = read(done)
    log.Println("total=%d", total)    // 0+1+2+3+4 = 10
    if total == 10 { ret 42 }
    ret 0
}
