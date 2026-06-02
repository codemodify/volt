package main

// Negative test: struct equality (`p1 == p2` where p1 and p2 are
// struct values) used to produce the cryptic clang IR error
// "icmp requires integer operands". Now surfaces at the volt
// source with an actionable message pointing at the workaround
// (compare field-by-field).
//
// Expected error: struct equality (==) is not supported in v0.7 — compare field-by-field instead

type Point struct {
	x int
	y int
}

fun main() int {
	var p1 Point = new Point{x: 1, y: 2}
	var p2 Point = new Point{x: 1, y: 2}
	if p1 == p2 { ret 42 }
	ret 0
}
