// Partial borrows (item 3): `&mut s.field` and `&mut a[i]` borrow the
// address of a struct field / slice element. The borrow's lifetime is
// (conservatively) tied to the whole container.
package main
import "log"

type Point struct {
	x int
	y int
}

fun bump(p &mut int) {
	*p = *p + 1
}

fun main() int {
	var pt Point = new Point {x: 10, y: 20}

	// Borrow a single field mutably and write through it.
	{
		var fx &mut int = &mut pt.x
		*fx = *fx + 5
		if *fx != 15 { ret 1 }
	}
	if pt.x != 15 { ret 2 }

	// Pass a field's address into a function.
	bump(&mut pt.y)
	if pt.y != 21 { ret 3 }

	// Shared field borrow (read-only view).
	{
		var ry &int = &pt.y
		if *ry != 21 { ret 4 }
	}

	// Slice element partial borrow.
	var s []int = new(4) []int {1, 2, 3, 4}
	{
		var e2 &mut int = &mut s[2]
		*e2 = *e2 * 10
		if *e2 != 30 { ret 5 }
	}
	if s[2] != 30 { ret 6 }

	bump(&mut s[0])
	if s[0] != 2 { ret 7 }

	log.Println("partial borrow ok: pt.x=%d pt.y=%d s[2]=%d", pt.x, pt.y, s[2])
	ret 42
}
