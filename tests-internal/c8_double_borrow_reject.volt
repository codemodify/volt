// C8 phase 4: holding TWO mutable borrows of the same variable
// simultaneously must be rejected. Many shared `&T` borrows are
// allowed concurrently, but `&mut T` is exclusive — once one is held,
// no other borrow (shared OR mut) of the same source is allowed.
package main

fun main() int {
	var x int = 10
	var b1 &mut int = &mut x
	var b2 &mut int = &mut x  // rejected: x already has &mut at b1
	ret *b1 + *b2
}
