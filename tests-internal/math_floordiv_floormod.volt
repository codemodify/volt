package main
import "log"
import "math"

// Positive test: math.FloorDivInt + math.FloorModInt.

fun main() int {
	var pass int = 0

	// FloorDivInt — positive operands match regular /.
	if math.FloorDivInt(10, 3) == 3 { pass = pass + 1 }
	if math.FloorDivInt(9, 3) == 3 { pass = pass + 1 }
	if math.FloorDivInt(0, 5) == 0 { pass = pass + 1 }

	// FloorDivInt — negative dividend goes more negative.
	if math.FloorDivInt(-7, 2) == -4 { pass = pass + 1 }
	if math.FloorDivInt(-1, 2) == -1 { pass = pass + 1 }
	if math.FloorDivInt(-6, 2) == -3 { pass = pass + 1 }   // exact: no adjustment

	// FloorDivInt — negative divisor.
	if math.FloorDivInt(7, -2) == -4 { pass = pass + 1 }
	if math.FloorDivInt(-7, -2) == 3 { pass = pass + 1 }   // both negative: positive result

	// FloorDivInt — degenerate b=0.
	if math.FloorDivInt(5, 0) == 0 { pass = pass + 1 }

	// FloorModInt — positive operands match regular %.
	if math.FloorModInt(10, 3) == 1 { pass = pass + 1 }
	if math.FloorModInt(9, 3) == 0 { pass = pass + 1 }

	// FloorModInt — sign-of-divisor result.
	if math.FloorModInt(-7, 2) == 1 { pass = pass + 1 }
	if math.FloorModInt(-1, 2) == 1 { pass = pass + 1 }
	if math.FloorModInt(7, -2) == -1 { pass = pass + 1 }
	if math.FloorModInt(-7, -2) == -1 { pass = pass + 1 }

	// FloorModInt — exact divisions return 0.
	if math.FloorModInt(-6, 2) == 0 { pass = pass + 1 }

	// FloorModInt — degenerate b=0.
	if math.FloorModInt(5, 0) == 0 { pass = pass + 1 }

	// Identity: FloorDivInt(a, b) * b + FloorModInt(a, b) == a (for b != 0).
	if math.FloorDivInt(-7, 2) * 2 + math.FloorModInt(-7, 2) == -7 { pass = pass + 1 }
	if math.FloorDivInt(7, -2) * -2 + math.FloorModInt(7, -2) == 7 { pass = pass + 1 }
	if math.FloorDivInt(-13, 5) * 5 + math.FloorModInt(-13, 5) == -13 { pass = pass + 1 }

	// Identity: FloorModInt result has same sign as b (or 0).
	// b=2, FloorMod result is in [0, 1].
	if math.FloorModInt(-100, 7) >= 0 { pass = pass + 1 }
	if math.FloorModInt(100, 7) >= 0 { pass = pass + 1 }
	if math.FloorModInt(-1, -3) <= 0 { pass = pass + 1 }
	if math.FloorModInt(1, -3) <= 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
