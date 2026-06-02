package main

// Negative test: a self-referencing const must produce a friendly
// volt-level error rather than blowing the Go stack via infinite
// recursion in the const-substitution path. (Earlier this would
// crash the compiler with `runtime: goroutine stack exceeds ...`.)
//
// Expected error: constant "X" is self-referential (depends on its own value)

const X int = X + 1

fun main() int {
	ret X
}
