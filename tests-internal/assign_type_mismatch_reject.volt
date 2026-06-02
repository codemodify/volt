package main

// Negative test: assigning a string to an int-typed variable must
// produce a friendly volt-level error at the assignment statement
// (the var-decl case is covered by type_mismatch_reject.volt).
//
// Expected error: cannot assign string value to int variable

fun main() int {
	var x int = 5
	x = "not an int"
	ret x
}
