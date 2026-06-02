package main

import "log"

type Point struct {
    x int
    y int
}

fun producer(out chan write Point) {
    def close(out)
    for i:=0; i < 3; i++ {
        var p Point = new Point {x: i, y: i*i}
        write(out, p)
    }
}

fun main() int {
    var ch chan Point = new(4)
    run producer(ch)
    var total int = 0
    for {
        p, ok := read(ch)
        if !ok { break }
        total = total + p.x + p.y
    }
    log.Println("total=%d", total)
    if total == 8 { ret 42 }
    ret 0
}
