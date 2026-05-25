// chanNN int — Many Readers, Many Writers (compile-time contract).
// 3 producers and 2 consumers all racing on the same channel.

package main

import "log"

fun producer(jobs chan write int) {
    for i := 0; i < 5; i++ { write(jobs, 1) }
}

fun consumer(jobs chan read int, done chan write int) {
    var sum int = 0
    for i := 0; i < 5; i++ {
        sum = sum + read(jobs)              // 5 reads each → 10 total drained
    }
    write(done, sum)
}

fun main() int {
    var jobs chanNN int = new(16)
    var done chan1N int = new(4)             // many writers (2 consumers), 1 reader (main)
    // 3 producers, 5 writes each = 15 writes total; 2 consumers read 5 each = 10 reads.
    // (Imbalance is fine — channel buffer holds the excess.)
    var producers int = 3
    for i := 0; i < producers; i++ { run producer(jobs) }
    var consumers int = 2
    for i := 0; i < consumers; i++ { run consumer(jobs, done) }
    var total int = 0
    for i := 0; i < 2; i++ { total = total + read(done) }
    log.Println("total=%d", total)            // 2 * 5 = 10
    if total == 10 { ret 42 }
    ret 0
}
