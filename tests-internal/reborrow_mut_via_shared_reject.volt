// Reborrow rejection: you cannot obtain `&mut` exclusive access by
// reborrowing through a shared `&T`. The checker must reject this —
// it would let two paths mutate the same storage without exclusivity.
package main

fun main() int {
	var x int = 10
	var s &int = &x            // shared borrow
	var m &mut int = &mut *s   // ERROR: &mut through shared borrow
	*m = 99
	ret 0
}
