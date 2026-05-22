// v0.4: struct type + new T{...} + field access.
// 30 + 12 = 42.

package main

type Point struct {
    x int
    y int
}

fun main() int {
    var p Point = new Point{x: 30, y: 12}
    ret p.x + p.y
}
