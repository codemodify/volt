package main

// Negative test: assigning a string literal to an int-typed variable
// must produce a friendly volt-level error, not a cryptic LLVM IR
// store-type mismatch from clang.
//
// Expected error: cannot assign string value to int variable

fun main() int {
	var x int = "not an int"
	ret x
}
