// Reborrow rejection: you cannot obtain a write borrow (`*T`) exclusive
// access by reborrowing through a shared read borrow (`&T`). The checker
// must reject this — it would let two paths mutate the same storage
// without exclusivity.
package main

fun main() int {
	var x int = 10
	var s &int = &x          // shared read borrow (`&T`)
	var m *int = &*s         // ERROR: write borrow (`*T`) through shared read borrow
	*m = 99
	ret 0
}
