// C8 reborrow: `&*b` creates a new borrow sharing the source's
// storage. A write reborrow (`*T`) needs the source to be a write
// borrow; a shared read reborrow (`&T`) works from either.
package main
import "log"

fun bump(p *int) {
	*p = *p + 1
}

fun main() int {
	var x int = 10

	{
		var b *int = &x
		// Write reborrow (`*T`): rb aliases the same storage as b.
		var rb *int = &*b
		*rb = *rb + 5
		if *b != 15 { ret 1 }

		// Pass a fresh write reborrow into a function.
		bump(&*b)
		if *rb != 16 { ret 2 }
	}

	// x writable again after the borrows end.
	x = 100
	if x != 100 { ret 3 }

	{
		var b *int = &x
		// Shared read reborrow (`&T`, downgrade from a write source): read-only view.
		var sr &int = &*b
		var v int = *sr
		if v != 100 { ret 4 }
		// Still can write through the write borrow original.
		*b = 200
	}
	if x != 200 { ret 5 }

	// Shared-from-shared reborrow.
	{
		var s &int = &x
		var s2 &int = &*s
		if *s2 != 200 { ret 6 }
	}

	log.Println("reborrow ok: x=%d", x)
	ret 42
}
