package main

// Negative test: declaring a local var with the same name as a
// function parameter used to silently overwrite the param's
// symbol-table entry — the caller's argument was lost. Now the
// same-scope-redeclare check catches it because parameters get
// registered in declaredAt at depth 0 alongside locals.
//
// Expected error: local variable "a" redeclared in the same scope (first at ...)

fun add(a int) int {
	var a int = 10
	ret a
}

fun main() int {
	ret add(5)
}
