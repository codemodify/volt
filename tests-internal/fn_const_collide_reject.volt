package main

// Negative test: a top-level function and constant sharing a name
// used to silently coexist — calls resolved to the function, but
// `var x = Foo` (bare value reference) resolved to the constant
// because `emitIdent` consults consts before funcs. Different
// answers in different contexts is the kind of bug nobody enjoys
// debugging. Now caught at registration time.
//
// Expected error: function "Foo" collides with earlier top-level declaration (first at ...)

const Foo int = 5

fun Foo() int {
	ret 7
}

fun main() int {
	var x int = Foo
	ret x
}
