package main

import "log"

fun main() int {
    var m map[string]int = new {"alpha": 10, "bravo": 20, "charlie": 30}
    var total int = 0
    var count int = 0
    for k, v := range m {
        total = total + v
        count = count + 1
        log.Println("%s -> %d", k, v)
    }
    log.Println("total=%d count=%d", total, count)
    if total == 60 {
        if count == 3 { ret 42 }
    }
    ret 0
}
