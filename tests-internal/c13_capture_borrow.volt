// C13 capture-by-borrow: closures can now capture held borrows.
// The env stores the borrow pointer; reading/writing through it
// inside the closure body works the same as outside. Mutation of
// the source value is observable through the captured borrow.
//
// SOUNDNESS: this is safe AS LONG AS the closure doesn't outlive
// the borrowed value. Returning a closure that captures a borrow
// is unsound but partially guarded by the existing escape-borrow
// check. Full proof requires C8 phase 3 lifetime tracking.
package main
import "log"

fun main() int {
	// 1. Basic read through captured borrow + mutation through the
	// captured write borrow (`*int`) is observable on the source. C8
	// phase 5 freezes the source during the borrow's life — we mutate
	// via the borrow itself rather than directly.
	var x int = 5
	{
		var b *int = &x
		var get fun() int = fun() int { ret *b }
		var setX fun(int) = fun(v int) { *b = v }
		if get() != 5 { ret 1 }
		setX(42)
		if get() != 42 { ret 2 }
	}

	// 3. Closure that writes through the borrow.
	var p int = 0
	var bp *int = &p
	var setNine fun() = fun() { *bp = 9 }
	setNine()
	if p != 9 { ret 3 }

	// 4. Two closures sharing the same captured borrow.
	var q int = 100
	var bq *int = &q
	var getQ fun() int = fun() int { ret *bq }
	var addToQ fun(int) = fun(d int) { *bq = *bq + d }
	addToQ(50)
	if getQ() != 150 { ret 4 }
	addToQ(-25)
	if q != 125 { ret 5 }

	// 5. Borrow capture composes with by-move capture. We write
	// through the borrow instead of directly to m (phase 5 freezes m
	// while bm is alive).
	var m int = 7
	{
		var bm *int = &m
		var k int = 3
		var add fun() int = fun() int { ret *bm + k }
		var setM fun(int) = fun(v int) { *bm = v }
		if add() != 10 { ret 6 }
		setM(17)
		if add() != 20 { ret 7 }
	}

	log.Println("ok")
	ret 42
}
