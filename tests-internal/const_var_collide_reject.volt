package main

// Negative test: a local var whose name collides with a top-level
// const used to silently still resolve to the const's value because
// `emitIdent` consults the const table before the local symbol
// table — a quiet correctness bug (the user's assignment would be
// invisible at every later read). Now caught at the var-decl site.
//
// Expected error: local variable "X" collides with top-level constant of the same name

const X int = 5

fun main() int {
	var X int = 10
	ret X
}
