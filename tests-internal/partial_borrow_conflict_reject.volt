// Partial-borrow conflict (C8 phase 7): disjoint fields CAN be write
// borrowed at once (`&pt.x` into `*int` + `&pt.y` into `*int` is fine),
// but a whole-container write borrow (`&pt` into `*Point`) while a field
// of pt is still borrowed must be rejected — the whole-var write borrow
// would alias the live field borrow.
package main

type Point struct {
	x int
	y int
}

fun main() int {
	var pt Point = new Point {x: 1, y: 2}
	var bx *int = &pt.x
	var whole *Point = &pt   // ERROR: field pt.x still borrowed
	*bx = 10
	whole.y = 20
	ret 0
}
