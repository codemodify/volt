// Partial-borrow conflict: borrowing one field mutably freezes the
// WHOLE container (conservative). A second mutable borrow of another
// field while the first is live must be rejected — volt doesn't yet
// track disjoint field borrows.
package main

type Point struct {
	x int
	y int
}

fun main() int {
	var pt Point = new Point {x: 1, y: 2}
	var bx &mut int = &mut pt.x
	var by &mut int = &mut pt.y   // ERROR: pt already mutably borrowed
	*bx = 10
	*by = 20
	ret 0
}
