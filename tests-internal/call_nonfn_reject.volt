package main

// Negative test: calling a name that resolves to a non-function local
// must produce a friendly "cannot call <name> — it has type T, not a
// function" rather than the misleading "undefined function".
//
// Expected error: cannot call "x" — it has type int, not a function

fun main() int {
	var x int = 5
	ret x(1, 2)
}
