package main

// Positive test: `fun f() *T { ret new T{...} }` heap-allocates the
// struct and returns the ptr. Matches the existing var-decl
// implicit-box rule. Without it, the ret site fails clang with the
// struct-vs-ptr mismatch.

type Box struct {
	x int
}

fun make() *Box {
	ret new Box{x: 42}
}

fun pair() (*Box, *Box) {
	ret new Box{x: 7}, new Box{x: 35}
}

fun main() int {
	var b *Box = make()
	if b.x != 42 { ret 1 }

	a, c := pair()
	if a.x + c.x != 42 { ret 2 }

	ret 42
}
