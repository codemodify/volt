package main

// Negative test: `fun main` is the program entry point and has a
// fixed signature — no parameters, at most one `int` return. A
// string return used to produce the misleading
// "type mismatch: cannot use string value where string is expected"
// because main is force-lowered to i64 internally.
//
// Expected error: `fun main` must return `int` (the exit code), not another type

fun main() string {
	ret "hi"
}
