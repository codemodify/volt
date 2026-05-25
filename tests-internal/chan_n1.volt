// chanN1 int — Many Readers, One Writer (compile-time contract).
// One producer, multiple workers reading distinct values.

package main

import "log"

fun worker(jobs chan read int, done chan write int) {
    var sum int = 0
    for i := 0; i < 5; i++ {
        sum = sum + read(jobs)
    }
    write(done, sum)
}

fun producer(jobs chan write int) {
    for i := 1; i <= 15; i++ { write(jobs, i) }
}

fun main() int {
    var jobs chanN1 int = new(16)
    var done chan1N int = new(8)           // 3 workers write, main reads → 1 reader many writers
    run producer(jobs)                     // single writer (no loop)
    for i := 0; i < 3; i++ {
        run worker(jobs, done)             // many readers (loop spawn)
    }
    var total int = 0
    for i := 0; i < 3; i++ {
        total = total + read(done)
    }
    log.Println("total=%d", total)         // 1+2+...+15 = 120
    if total == 120 { ret 42 }
    ret 0
}
