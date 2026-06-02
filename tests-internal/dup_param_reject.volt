package main

// Negative test: a function with two parameters of the same name
// used to surface only as a cryptic clang IR error
// `redefinition of argument '%a'`. Now caught at the volt-level
// declaration site, naming the function and offending parameter.
//
// Expected error: function "add" has duplicate parameter "a"

fun add(a int, a int) int {
	ret a + a
}

fun main() int {
	ret add(1, 2)
}
