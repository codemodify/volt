package main

// Positive test: method dispatch on a call result (`makeBox(42).GetX()`)
// used to require a temp local; now `emitMethodCall` spills the
// call result into a fresh stack slot automatically.

type Box struct {
	x int
}

fun makeBox(n int) Box {
	ret new Box{x: n}
}

fun (b *Box) GetX() int {
	ret b.x
}

fun main() int {
	ret makeBox(42).GetX()
}
