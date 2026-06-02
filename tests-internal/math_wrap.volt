package main
import "log"
import "math"

fun main() int {
	var pass int = 0

	// In range → unchanged.
	if math.WrapInt(5, 0, 10) == 5 { pass = pass + 1 }
	if math.WrapInt(0, 0, 10) == 0 { pass = pass + 1 }
	if math.WrapInt(10, 0, 10) == 10 { pass = pass + 1 }

	// Wrap from above (one cycle).
	if math.WrapInt(11, 0, 10) == 0 { pass = pass + 1 }
	if math.WrapInt(12, 0, 10) == 1 { pass = pass + 1 }
	if math.WrapInt(21, 0, 10) == 10 { pass = pass + 1 }

	// Wrap from above (two cycles).
	if math.WrapInt(22, 0, 10) == 0 { pass = pass + 1 }
	if math.WrapInt(33, 0, 10) == 0 { pass = pass + 1 }

	// Wrap from below.
	if math.WrapInt(-1, 0, 10) == 10 { pass = pass + 1 }
	if math.WrapInt(-2, 0, 10) == 9 { pass = pass + 1 }
	if math.WrapInt(-11, 0, 10) == 10 { pass = pass + 1 }
	if math.WrapInt(-12, 0, 10) == 10 { pass = pass + 1 }

	// Degenerate range (hi < lo) → lo.
	if math.WrapInt(5, 10, 0) == 10 { pass = pass + 1 }

	// Single-point range → lo.
	if math.WrapInt(5, 7, 7) == 7 { pass = pass + 1 }
	if math.WrapInt(7, 7, 7) == 7 { pass = pass + 1 }

	// Non-zero lo. Range [3, 7], span=5.
	if math.WrapInt(3, 3, 7) == 3 { pass = pass + 1 }
	if math.WrapInt(8, 3, 7) == 3 { pass = pass + 1 }
	if math.WrapInt(13, 3, 7) == 3 { pass = pass + 1 }
	if math.WrapInt(2, 3, 7) == 7 { pass = pass + 1 }

	// Negative range.
	if math.WrapInt(-5, -10, -1) == -5 { pass = pass + 1 }
	if math.WrapInt(0, -10, -1) == -10 { pass = pass + 1 }
	if math.WrapInt(-11, -10, -1) == -1 { pass = pass + 1 }

	// Angle wrap-around: 0..359 degrees.
	if math.WrapInt(360, 0, 359) == 0 { pass = pass + 1 }
	if math.WrapInt(720, 0, 359) == 0 { pass = pass + 1 }
	if math.WrapInt(-1, 0, 359) == 359 { pass = pass + 1 }
	if math.WrapInt(-90, 0, 359) == 270 { pass = pass + 1 }

	// Day-of-week (0..6).
	if math.WrapInt(7, 0, 6) == 0 { pass = pass + 1 }
	if math.WrapInt(-1, 0, 6) == 6 { pass = pass + 1 }
	if math.WrapInt(15, 0, 6) == 1 { pass = pass + 1 }

	// Cross-property: WrapInt result is in InRange.
	var w1 int = math.WrapInt(1000, 0, 7)
	if math.InRange(w1, 0, 7) { pass = pass + 1 }
	var w2 int = math.WrapInt(-1000, 0, 7)
	if math.InRange(w2, 0, 7) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 30 { ret 42 }
	ret 0
}
