package main

// Negative test: an undefined identifier whose name is close to an
// in-scope name must produce a "did you mean ...?" suggestion via
// edit-distance matching.
//
// Expected error: undefined identifier "cuonter" (did you mean "counter"?)

fun main() int {
	var counter int = 5
	var x int = counter
	var y int = cuonter
	ret y + x
}
