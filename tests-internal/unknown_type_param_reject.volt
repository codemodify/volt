package main

// Negative test: an unknown type in a function parameter must
// surface at the parameter position, not as a downstream argument
// mismatch when the function is called. Catches typos like
// `fun f(x Pont)` (meant Point) at the signature itself.
//
// Expected error: unknown type "Foo"

fun add(a Foo, b int) int {
	ret b
}

fun main() int {
	ret add(0, 1)
}
