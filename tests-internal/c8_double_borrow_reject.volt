// C8 phase 4: holding TWO write borrows of the same variable
// simultaneously must be rejected. Many shared read borrows (`&T`) are
// allowed concurrently, but a write borrow (`*T`) is exclusive — once one
// is held, no other borrow (shared OR write) of the same source is allowed.
package main

fun main() int {
	var x int = 10
	var b1 *int = &x
	var b2 *int = &x  // rejected: x already has a write borrow at b1
	ret *b1 + *b2
}
