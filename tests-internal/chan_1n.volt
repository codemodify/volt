// chan1N int — One Reader, Many Writers (compile-time contract).
// 5 producers spawned in a loop; main is the sole reader.

package main

import "log"

fun producer(jobs chan write int, id int) {
    write(jobs, id)
}

fun main() int {
    var jobs chan1N int = new(8)
    for i := 1; i <= 5; i++ {
        run producer(jobs, i)             // "many" producers (loop spawn)
    }
    var sum int = 0
    for i := 0; i < 5; i++ {              // single reader (main)
        sum = sum + read(jobs)
    }
    log.Println("sum=%d", sum)            // 1+2+3+4+5 = 15
    if sum == 15 { ret 42 }
    ret 0
}
