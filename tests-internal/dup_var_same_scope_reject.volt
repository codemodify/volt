package main

// Negative test: `var x; var x` at the same flat scope used to
// silently overwrite the first symbol's table entry — the user's
// first declaration became unreachable and any drops it registered
// would never fire. Now caught at the second declaration.
//
// Sibling scopes still get to reuse names (sequential for-loops,
// if/else blocks both declaring a temp variable, etc.).
//
// Expected error: local variable "x" redeclared in the same scope

fun main() int {
	var x int = 5
	var x int = 10
	ret x
}
