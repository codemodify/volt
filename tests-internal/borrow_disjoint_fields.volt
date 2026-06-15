// C8 phase 7: disjoint struct fields can take write borrows (`*T`) at
// the same time (`&s.x` + `&s.y`) — distinct fields don't alias.
// Mixing a shared read borrow (`&T`) and a write borrow (`*T`) on
// different fields is also fine. A second borrow of the SAME field, or
// a whole-struct borrow while a field is live, is rejected (see
// partial_borrow_conflict_reject).
package main
import "log"

type Rect struct {
	w int
	h int
}

fun bump(p *int) { *p = *p + 1 }

fun main() int {
	var r Rect = new Rect {w: 3, h: 4}

	// Two distinct fields, both write borrows, at once.
	{
		var bw *int = &r.w
		var bh *int = &r.h
		*bw = *bw * 10
		*bh = *bh * 100
		if *bw != 30 { ret 1 }
		if *bh != 400 { ret 2 }
	}
	if r.w != 30 { ret 3 }
	if r.h != 400 { ret 4 }

	// Pass two distinct fields into a mutating function in sequence.
	bump(&r.w)
	bump(&r.h)
	if r.w != 31 { ret 5 }
	if r.h != 401 { ret 6 }

	// Shared read borrow on w + write borrow on h simultaneously.
	{
		var sw &int = &r.w
		var mh *int = &r.h
		if *sw != 31 { ret 7 }
		*mh = 0
	}
	if r.h != 0 { ret 8 }

	// After all field borrows end, the field slots are released, so the
	// same field can be borrowed again.
	{
		var bw2 *int = &r.w
		*bw2 = 7
	}
	if r.w != 7 { ret 9 }

	log.Println("disjoint fields ok: w=%d h=%d", r.w, r.h)
	ret 42
}
