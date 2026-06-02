package main

// Positive test: field assignment through slice/map index results
// (`s[0].x = 42`, `m["k"].x = 42`). Same machinery as nested
// SelectorExpr LHSes — emitFieldAssign now dispatches on
// SelectorExpr, IndexExpr, and CallExpr LHSes through the same
// container-pointer + GEP store path.

type Box struct {
	x int
}

fun main() int {
	// Slice index field assignment.
	var s []*Box = new(2) []*Box{new Box{x: 0}, new Box{x: 0}}
	s[0].x = 7
	s[1].x = 35
	if s[0].x + s[1].x != 42 { ret 1 }

	// Map index field assignment.
	var m map[string]*Box = new {"a": new Box{x: 0}}
	m["a"].x = 42
	if m["a"].x != 42 { ret 2 }

	ret 42
}
