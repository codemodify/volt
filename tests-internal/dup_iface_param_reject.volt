package main

// Negative test: a duplicate parameter name inside an interface
// method signature used to be silently accepted (the FuncDecl
// dup-param check from Pass 154 didn't cover interface
// method-type signatures). Now caught at the interface decl.
//
// Expected error: interface "X" method "Foo" has duplicate parameter "a"

type X interface {
	Foo(a int, a int) int
}

fun main() int {
	ret 0
}
