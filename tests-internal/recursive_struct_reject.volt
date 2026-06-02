package main

// Negative test: a struct that directly contains itself by value
// must produce a friendly volt-level error pointing at the type
// declaration — not the previous cryptic clang IR error
// `identified structure type 'Node' is recursive`.
//
// Expected error: struct "Node" contains a field of type "Node" by value — recursive structs need `*T` (pointer) or `&T` (borrow) indirection

type Node struct {
	val  int
	next Node
}

fun main() int {
	ret 0
}
