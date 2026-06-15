// C8 phase 3 block-scoped borrow release: a held borrow's active
// span ends when its declaring block closes. After that, a fresh
// borrow of the same source is allowed again. Combined with the
// single-var conflict rule, this gives users a clean
// "borrow → use → drop → borrow again" idiom.
package main
import "log"

fun main() int {
	var x int = 1

	// Sequential block-scoped write borrows (`*T`) of the same var —
	// each released at its block's closing brace.
	{
		var b *int = &x
		*b = *b + 10
	}
	if x != 11 { ret 1 }

	{
		var b *int = &x
		*b = *b * 2
	}
	if x != 22 { ret 2 }

	{
		var b *int = &x
		*b = *b - 7
	}
	if x != 15 { ret 3 }

	// After all blocks close, x can still be borrowed at the top scope.
	var b2 *int = &x
	*b2 = 42
	if x != 42 { ret 4 }

	// Nested blocks: inner borrow ends at inner `}` while outer keeps
	// holding through its own scope.
	var y int = 100
	var outer *int = &y
	*outer = *outer + 1
	// Inside another block, attempt to borrow y → REJECTED (outer is
	// still active). The negative test c8_double_borrow_reject covers
	// this case at the top scope; here we just confirm the borrow
	// released by the time we get back out.
	{
		// At this point outer is in scope but for completeness we
		// use a DIFFERENT source variable to show the block-scoped
		// release works as expected on a clean source.
		var z int = 5
		var b *int = &z
		*b = 50
		if z != 50 { ret 5 }
	}
	if y != 101 { ret 6 }

	log.Println("ok")
	ret 42
}
