// C8 phase 4: multiple shared `&T` borrows of the same source are
// allowed concurrently. Demonstrates the read-parallelism the
// mutable/shared split unlocks. `&mut T` still excludes everything
// else (negative tests cover this separately).
package main
import "log"

fun main() int {
	var x int = 42

	// Three concurrent shared borrows of x — all read-only.
	// Wrap in a block so they release before the &mut below.
	{
		var a &int = &x
		var b &int = &x
		var c &int = &x
		var sum int = *a + *b + *c
		if sum != 126 { ret 1 }
	}

	// Nested shared borrows release at their block's end.
	{
		var p &int = &x
		var q &int = &x
		var two int = *p + *q
		if two != 84 { ret 2 }
	}

	// After both blocks close, shared borrows released. Can take mut.
	var m &mut int = &mut x
	*m = 7
	if x != 7 { ret 3 }

	log.Println("ok")
	ret 42
}
