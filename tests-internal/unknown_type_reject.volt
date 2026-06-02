package main

// Negative test: referencing an unknown type in a var declaration
// used to silently lower to LLVM void and surface only as a downstream
// "cannot use int value where Foo is expected" — confusing because
// the user reads it as if Foo exists. Now the type validation walks
// pointer / borrow / slice / map wrappers and rejects unresolved
// NamedTypes upfront, with a did-you-mean hint when close to a known
// type.
//
// Expected error: unknown type "Pont" (did you mean "Point"?)

type Point struct {
	x int
}

fun main() int {
	var p Pont = new Pont{x: 5}
	ret p.x
}
