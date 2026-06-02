package main

// Negative test: a struct with two fields of the same name used to
// silently keep only the second one (the field-index map quietly
// overwrote on insert). Now the compiler rejects it at the
// type-decl with a duplicate-field error.
//
// Expected error: struct "Point" has duplicate field "x" (first at ...)

type Point struct {
	x int
	x int
}

fun main() int {
	var p Point = new Point{x: 5}
	ret p.x
}
