// Cross-function lifetime tracking: passing &x (shared read borrow)
// or &x bound to a *T param (write borrow) to a function is fine when
// no conflicting borrow is held. The borrow is "live" for the
// duration of the call and released on return.
package main
import "log"

fun bump(p *int) {
	*p = *p + 1
}

fun getVal(p &int) int {
	ret *p
}

fun sumTwo(a &int, b &int) int {
	ret *a + *b
}

fun main() int {
	// Sequential write-borrow calls: each &x (bound to the *int
	// param) is released on return.
	var x int = 10
	bump(&x)
	bump(&x)
	bump(&x)
	if x != 13 { ret 1 }

	// Shared reads after writes complete.
	var v int = getVal(&x)
	if v != 13 { ret 2 }

	// Multiple shared borrows in the SAME call (siblings) — allowed
	// because they're all read-only.
	var y int = 7
	var z int = 5
	var t int = sumTwo(&y, &z)
	if t != 12 { ret 3 }

	// Bare-name passing (volt auto-infers borrow): identical behavior.
	bump(x)  // same as bump(&x) since param is *int (write borrow)
	if x != 14 { ret 4 }

	log.Println("ok")
	ret 42
}
