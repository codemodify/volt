package main
import "log"
import "math"

// Positive test: math.IsEven + IsOdd + NextEvenInt + NextOddInt.

fun main() int {
	var pass int = 0

	// IsEven.
	if math.IsEven(0) { pass = pass + 1 }
	if math.IsEven(2) { pass = pass + 1 }
	if math.IsEven(100) { pass = pass + 1 }
	if math.IsEven(-2) { pass = pass + 1 }
	if math.IsEven(-100) { pass = pass + 1 }
	if !math.IsEven(1) { pass = pass + 1 }
	if !math.IsEven(3) { pass = pass + 1 }
	if !math.IsEven(99) { pass = pass + 1 }

	// IsOdd — note that volt's `(n & 1) == 1` is signed-int specific;
	// for -1 (0xFFFF...FF) & 1 = 1, so IsOdd(-1) is true. Test.
	if math.IsOdd(1) { pass = pass + 1 }
	if math.IsOdd(3) { pass = pass + 1 }
	if math.IsOdd(99) { pass = pass + 1 }
	if !math.IsOdd(0) { pass = pass + 1 }
	if !math.IsOdd(2) { pass = pass + 1 }
	if !math.IsOdd(-2) { pass = pass + 1 }

	// Parity invariant.
	if math.IsEven(0) {
		if !math.IsOdd(0) { pass = pass + 1 }
	}

	// NextEvenInt.
	if math.NextEvenInt(0) == 2 { pass = pass + 1 }
	if math.NextEvenInt(1) == 2 { pass = pass + 1 }
	if math.NextEvenInt(2) == 4 { pass = pass + 1 }
	if math.NextEvenInt(3) == 4 { pass = pass + 1 }
	if math.NextEvenInt(99) == 100 { pass = pass + 1 }
	if math.NextEvenInt(-4) == -2 { pass = pass + 1 }
	if math.NextEvenInt(-3) == -2 { pass = pass + 1 }

	// NextOddInt.
	if math.NextOddInt(0) == 1 { pass = pass + 1 }
	if math.NextOddInt(1) == 3 { pass = pass + 1 }
	if math.NextOddInt(2) == 3 { pass = pass + 1 }
	if math.NextOddInt(100) == 101 { pass = pass + 1 }
	if math.NextOddInt(-1) == 1 { pass = pass + 1 }
	if math.NextOddInt(-2) == -1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 28 { ret 42 }
	ret 0
}
