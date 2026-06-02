package main

import "log"

fun sumWorker(s []int, done chan write int) {
    var total int = 0
    for _, v := range s {
        total = total + v
    }
    write(done, total)
}

fun main() int {
    var nums []int = new {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
    var done chan int = new(1)
    run sumWorker(nums, done)
    var total int = read(done)
    log.Println("total=%d", total)
    if total == 55 { ret 42 }
    ret 0
}
