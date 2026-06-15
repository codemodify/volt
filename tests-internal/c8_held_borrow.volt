// C8 held-borrow phase 1: `var b *T = &x` declares a write borrow that
// survives across statements. Read via `*b`, write via `*b = v`.
// Both are observable through the original `x`. The borrow's
// lifetime is bound to the declaration scope and the underlying
// value — the existing escape-borrow check + new write-through-borrow
// path keep the model sound.
package main
import "log"

fun main() int {
	// 1. Held write borrow (`*int`) + read through *b. Scoped to its own
	// block so the source `x` can be mutated directly afterward (C8 phase 5
	// rejects source mutation while a borrow is held).
	var x int = 42
	{
		var b *int = &x
		var v int = *b
		if v != 42 { ret 1 }

		// 2. Writing through *b is observable on x. (Direct source
		// mutation `x = 100` would be rejected while b is alive; we
		// only write through the borrow inside the borrow's scope.)
		*b = 100
	}
	if x != 100 { ret 2 }

	// 3. After borrow released, direct mutation allowed.
	x = 7

	// 4. Passing held borrow to a function (the borrow's scope ends at
	// the block close, so subsequent source mutation works).
	var v3 int = 0
	{
		var b2 *int = &x
		v3 = identity(b2)
	}
	if v3 != 7 { ret 4 }
	x = 50  // allowed: no active borrow.
	var _xdone int = x

	// 5. Multiple borrows of distinct values.
	var p int = 11
	var q int = 22
	var bp &int = &p
	var bq &int = &q
	var sum int = *bp + *bq
	if sum != 33 { ret 5 }

	// 6. Borrow inside a bare block — auto-released at block end so
	// the source can be moved (or used again) freely after.
	var k int = 9
	{
		var bk *int = &k
		*bk = 99
	}
	if k != 99 { ret 6 }

	log.Println("ok")
	ret 42
}

fun identity(p &int) int {
	ret p
}
