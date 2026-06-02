package main

// Negative test: a struct literal that names a non-existent field
// used to silently accept the bad entry and zero-initialize the
// missing real field — a subtle bug source. Now the unknown-field
// is rejected at the composite-literal position with a did-you-mean
// hint when close to a real field.
//
// Expected error: Point has no field "z" (did you mean "x"?)

type Point struct {
	x int
	y int
}

fun main() int {
	var p Point = new Point{x: 1, z: 2}
	ret p.x
}
