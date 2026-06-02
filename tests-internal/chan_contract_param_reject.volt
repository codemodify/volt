package main

// Negative test: channel multiplicity contracts on function parameters
// are now enforced (C18). The `chanN1 int` parameter means globally one
// writer; this function spawns multiple writers via `run w(ch)` inside
// a for-loop — an in-loop writer spawn definitely violates the
// at-most-1 cap from within the function's scope, regardless of what
// the caller might do.
//
// Expected error: chanN1 "ch" contract violated — parameter `One Writer` but a `run` writing to "ch" appears inside a loop

fun w(ch chan write int) {
	write(ch, 1)
}

fun bad(ch chanN1 int) {
	for i := 0; i < 3; i++ {
		run w(ch)
	}
}

fun main() int {
	var ch chanN1 int = new(8)
	run bad(ch)
	ret 42
}
