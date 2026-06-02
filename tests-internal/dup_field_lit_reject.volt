package main

// Negative test: a struct literal that lists the same field twice
// used to silently overwrite (the second value won via the
// provided-map last-write-wins). That hid copy-paste bugs where
// the user meant to write a different field on the second entry.
// Now duplicates are rejected at the second sighting.
//
// Expected error: field "x" listed twice in Point composite literal

type Point struct {
	x int
	y int
}

fun main() int {
	var p Point = new Point{x: 1, x: 2}
	ret p.x
}
