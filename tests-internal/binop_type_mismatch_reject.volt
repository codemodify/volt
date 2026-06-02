package main

// Negative test: binary arithmetic on mismatched types (e.g. int + string)
// must produce a friendly volt-level error at the operator position,
// not a cryptic clang IR `defined with type X but expected Y` error.
//
// Expected error: type mismatch in binary "+": int and string

fun main() int {
	var x int = 5 + "hello"
	ret x
}
