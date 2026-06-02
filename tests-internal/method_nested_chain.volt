package main

// Positive test: method dispatch through a deeply nested
// ptr-to-struct chain. `w.o.i.Get()` requires `spillFieldAsLocal`
// to recover the AST type of the inner-most receiver — for nested
// selector chains `e.X` is itself a SelectorExpr, so the same
// FEAT.11 recursion pattern applies here.

type Inner struct {
	x int
}

fun (i *Inner) Get() int {
	ret i.x
}

type Outer struct {
	i *Inner
}

type Wrap struct {
	o *Outer
}

fun main() int {
	var w Wrap = new Wrap{o: new Outer{i: new Inner{x: 42}}}
	ret w.o.i.Get()
}
