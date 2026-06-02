package main
import "log"
import "math"

// Positive test: math.PrevEvenInt + PrevOddInt + IsMultipleOf.

fun main() int {
	var pass int = 0

	// PrevEvenInt.
	if math.PrevEvenInt(0) == -2 { pass = pass + 1 }
	if math.PrevEvenInt(1) == 0 { pass = pass + 1 }
	if math.PrevEvenInt(2) == 0 { pass = pass + 1 }
	if math.PrevEvenInt(3) == 2 { pass = pass + 1 }
	if math.PrevEvenInt(100) == 98 { pass = pass + 1 }
	if math.PrevEvenInt(-3) == -4 { pass = pass + 1 }
	if math.PrevEvenInt(-4) == -6 { pass = pass + 1 }

	// PrevOddInt.
	if math.PrevOddInt(0) == -1 { pass = pass + 1 }
	if math.PrevOddInt(1) == -1 { pass = pass + 1 }
	if math.PrevOddInt(2) == 1 { pass = pass + 1 }
	if math.PrevOddInt(3) == 1 { pass = pass + 1 }
	if math.PrevOddInt(100) == 99 { pass = pass + 1 }
	if math.PrevOddInt(-2) == -3 { pass = pass + 1 }

	// IsMultipleOf positive.
	if math.IsMultipleOf(12, 3) { pass = pass + 1 }
	if math.IsMultipleOf(12, 4) { pass = pass + 1 }
	if math.IsMultipleOf(12, 12) { pass = pass + 1 }
	if math.IsMultipleOf(0, 5) { pass = pass + 1 }   // 0 is multiple of any non-zero
	if math.IsMultipleOf(1, 1) { pass = pass + 1 }
	if math.IsMultipleOf(100, 25) { pass = pass + 1 }

	// IsMultipleOf negative.
	if !math.IsMultipleOf(13, 4) { pass = pass + 1 }
	if !math.IsMultipleOf(7, 3) { pass = pass + 1 }
	if !math.IsMultipleOf(100, 7) { pass = pass + 1 }

	// b=0 → false.
	if !math.IsMultipleOf(5, 0) { pass = pass + 1 }
	if !math.IsMultipleOf(0, 0) { pass = pass + 1 }

	// Negative a — modulo behavior matters.
	if math.IsMultipleOf(-12, 3) { pass = pass + 1 }
	if math.IsMultipleOf(12, -3) { pass = pass + 1 }
	if math.IsMultipleOf(-12, -3) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
