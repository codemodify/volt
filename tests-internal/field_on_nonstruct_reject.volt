package main

// Negative test: trying to read/write a field on a value whose type
// is not a struct must produce a friendly error that names the
// receiver and its actual type — not the previous confusing
// "field is not a struct (type i64)" wording.
//
// Expected error: cannot read field "field" on "x" — it has type int, not a struct

fun main() int {
	var x int = 5
	ret x.field
}
