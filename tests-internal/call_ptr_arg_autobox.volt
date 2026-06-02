package main

// Positive test: passing a struct literal to a `*T` parameter
// auto-boxes the struct (heap-allocate + pass ptr). Matches the
// existing var-decl boxing for `var f *T = new T{...}`.
// Previously failed with "can only borrow from a variable in v0.3"
// because the non-ident arg path didn't know how to box.

type Box struct {
	x int
}

fun take(b *Box) int {
	ret b.x
}

fun main() int {
	ret take(new Box{x: 42})
}
