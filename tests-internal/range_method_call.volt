package main

// Positive test: method dispatch on a range-binding of type *T.
// Previously `for _, b := range s` over `[]*Box` produced a `b`
// symbol with Type=ptr but no Elem set, so `b.Method()` ended up
// passing the alloca-of-pointer instead of loading the pointer
// first — methods saw garbage receivers. Fix: set Elem on the
// range binding so the method-call's pointer-receiver-with-borrow
// branch fires.

type Box struct {
	x int
}

fun (b *Box) Get() int {
	ret b.x
}

fun main() int {
	var s []*Box = new(2) []*Box{new Box{x: 7}, new Box{x: 35}}
	var total int = 0
	for _, b := range s {
		total = total + b.Get()
	}
	if total != 42 { ret 1 }
	ret 42
}
