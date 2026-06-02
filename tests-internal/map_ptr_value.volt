package main

// Positive test: `map[K]*T` end-to-end — literal init, set, and
// read all auto-box/unbox correctly. Stores go through ptrtoint
// into the i64 value slot (matching the interface-valued map
// path from IFACE.6/IFACE.7); reads cast back via inttoptr.

type Box struct {
	x int
}

fun main() int {
	// Literal init with a pointer-to-struct value.
	var m map[string]*Box = new {"a": new Box{x: 7}}

	// Explicit set on a separate key.
	var b Box = new Box{x: 35}
	m["b"] = b

	// Read both keys back as pointers and access their fields.
	if m["a"].x + m["b"].x != 42 { ret 1 }

	// Missing key returns nil ptr.
	if m["missing"] != nil { ret 2 }

	ret 42
}
