// chan11 int — One Reader, One Writer (compile-time contract).
// Producer is the writer, main is the reader.

package main

import "log"

fun producer(out chan write int) {
    for i := 0; i < 5; i++ { write(out, i) }
    close(out)
}

fun main() int {
    var ch chan11 int = new()
    run producer(ch)
    var sum int = 0
    for {
        v, ok := read(ch)
        if !ok { break }
        sum = sum + v
    }
    log.Println("sum=%d", sum)     // 0+1+2+3+4 = 10
    if sum == 10 { ret 42 }
    ret 0
}
