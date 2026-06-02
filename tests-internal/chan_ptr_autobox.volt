package main

// Positive test: `chan *T` (or `chan write *T`, `chan11 *T`, etc.)
// auto-boxes a struct literal sent on the channel. Previously this
// failed at the per-element store with struct-vs-ptr mismatch
// because the channel-send paths only auto-boxed for interface
// types, not pointer types.

type Box struct {
	x int
}

fun (b *Box) Get() int {
	ret b.x
}

fun worker(ch chan write *Box) {
	write(ch, new Box{x: 42})
}

fun main() int {
	var ch chan11 *Box = new()
	run worker(ch)
	var b *Box = read(ch)
	ret b.Get()
}
