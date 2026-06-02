package main

// Negative test: an interface that declares the same method name
// twice (often a copy-paste mistake) used to silently register both
// and let the interface-impl scan match whichever came last —
// resulting in surprising "does not implement" errors at use sites.
// Now caught at the type-decl with a friendly volt-level error.
//
// Expected error: interface "X" has duplicate method "Foo"

type X interface {
	Foo() int
	Foo() string
}

fun main() int {
	ret 0
}
