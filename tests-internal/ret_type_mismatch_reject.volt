package main

// Negative test: a function declared `int` returning a string literal
// must produce a friendly volt-level error at the ret site, not a
// cryptic clang IR ret-type error.
//
// Expected error: type mismatch: cannot use string value where int is expected

fun makeInt() int {
	ret "not an int"
}

fun main() int {
	ret makeInt()
}
