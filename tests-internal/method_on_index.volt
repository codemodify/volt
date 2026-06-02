package main

// Positive test: method dispatch on a slice/map index result
// (`s[i].Method()`, `m["k"].Method()`) used to require a temp
// local; now the index access is spilled automatically and the
// element/value AST type is recovered from the collection symbol.

type Box struct {
	x int
}

fun (b *Box) GetX() int {
	ret b.x
}

fun main() int {
	var s []Box = new(2) []Box{}
	s[0] = new Box{x: 7}
	s[1] = new Box{x: 35}

	var total int = s[0].GetX() + s[1].GetX()
	if total != 42 { ret 1 }
	ret 42
}
