package main

// Negative test: accessing a non-existent field on a struct whose
// name is close to a real field must produce a "did you mean ...?"
// suggestion via edit-distance matching.
//
// Expected error: Point has no field "cuonter" (did you mean "counter"?)

type Point struct {
	counter int
	y       int
}

fun main() int {
	var p Point = new Point{counter: 5, y: 3}
	ret p.cuonter
}
