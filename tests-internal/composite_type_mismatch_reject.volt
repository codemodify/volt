package main

// Negative test: composite-literal field mismatch must produce a
// friendly volt-level error at the field site, not a cryptic clang
// IR insertvalue error.
//
// Expected error: type mismatch: cannot use string value where int is expected

type Box struct {
	n int
	s string
}

fun main() int {
	var b Box = new Box{n: "wrong", s: "hi"}
	ret b.n
}
