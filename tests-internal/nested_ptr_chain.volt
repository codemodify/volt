package main

// Positive test: arbitrarily nested ptr-to-struct field chains
// `w.o.i.x` (each intermediate field is a *T) now resolve all the
// way through. `pointeeStructName` recurses into nested
// SelectorExpr.X so the auto-deref machinery walks the entire
// chain.

type Inner struct {
	x int
}

type Outer struct {
	i *Inner
}

type Wrap struct {
	o *Outer
}

fun main() int {
	var w Wrap = new Wrap{o: new Outer{i: new Inner{x: 42}}}
	ret w.o.i.x
}
