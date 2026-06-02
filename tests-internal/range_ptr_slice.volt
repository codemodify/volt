package main

// Positive test: range over `[]*T` exposes `v` as a ptr, and the
// FEAT.7 field-auto-deref machinery now also handles the bare-Ident
// receiver case — so `v.x` loads through the ptr. Before this pass,
// `pointeeStructName` only recognized CallExpr / IndexExpr /
// SelectorExpr inner expressions.

type Box struct {
	x int
}

fun main() int {
	var s []*Box = new(2) []*Box{new Box{x: 7}, new Box{x: 35}}
	var total int = 0
	for _, v := range s {
		total = total + v.x
	}
	if total != 42 { ret 1 }
	ret 42
}
