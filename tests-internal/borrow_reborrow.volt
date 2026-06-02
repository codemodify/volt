// C8 reborrow: `&mut *b` / `&*b` create a new borrow sharing the
// source's storage. A &mut reborrow needs the source to be &mut; a
// shared reborrow works from either.
package main
import "log"

fun bump(p &mut int) {
	*p = *p + 1
}

fun main() int {
	var x int = 10

	{
		var b &mut int = &mut x
		// Mutable reborrow: rb aliases the same storage as b.
		var rb &mut int = &mut *b
		*rb = *rb + 5
		if *b != 15 { ret 1 }

		// Pass a fresh mutable reborrow into a function.
		bump(&mut *b)
		if *rb != 16 { ret 2 }
	}

	// x writable again after the borrows end.
	x = 100
	if x != 100 { ret 3 }

	{
		var b &mut int = &mut x
		// Shared reborrow (downgrade from &mut source): read-only view.
		var sr &int = &*b
		var v int = *sr
		if v != 100 { ret 4 }
		// Still can write through the mutable original.
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
