// C13 escape proof: a closure that captures a borrow cannot be
// returned from a function — the caller's scope would see a
// dangling pointer to the borrow's source value (which dies when
// this function returns).
package main

fun bad() fun() int {
	var x int = 42
	var b &int = &x
	var f fun() int = fun() int { ret *b }
	ret f  // REJECTED: f captures &x, but x dies here
}

fun main() int { ret 0 }
