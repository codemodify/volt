package main

// Positive test: methods dispatch correctly when the receiver is a
// pointer field of a containing struct. Two things have to work:
// (a) the composite literal `new Outer{inner: new Inner{...}}`
// must auto-box the inner struct value into a heap pointer (same
// shape as `var f *T = new T{...}` does in emitVar); (b) the
// chained-method spill must set `Elem` on the synthetic recvSym so
// the pointer-receiver call loads the ptr correctly.

type Inner struct {
	x int
}

fun (i *Inner) Get() int {
	ret i.x
}

type Outer struct {
	inner *Inner
}

fun main() int {
	var o Outer = new Outer{inner: new Inner{x: 42}}
	ret o.inner.Get()
}
