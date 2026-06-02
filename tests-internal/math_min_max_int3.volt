package main
import "log"
import "math"

fun main() int {
	var pass int = 0

	// MinInt3 — every position can be the min.
	if math.MinInt3(1, 2, 3) == 1 { pass = pass + 1 }
	if math.MinInt3(2, 1, 3) == 1 { pass = pass + 1 }
	if math.MinInt3(2, 3, 1) == 1 { pass = pass + 1 }

	// MaxInt3 — every position can be the max.
	if math.MaxInt3(1, 2, 3) == 3 { pass = pass + 1 }
	if math.MaxInt3(1, 3, 2) == 3 { pass = pass + 1 }
	if math.MaxInt3(3, 1, 2) == 3 { pass = pass + 1 }

	// Negatives.
	if math.MinInt3(-1, -2, -3) == -3 { pass = pass + 1 }
	if math.MaxInt3(-1, -2, -3) == -1 { pass = pass + 1 }

	// Mixed signs.
	if math.MinInt3(-5, 0, 5) == -5 { pass = pass + 1 }
	if math.MaxInt3(-5, 0, 5) == 5 { pass = pass + 1 }

	// All equal.
	if math.MinInt3(7, 7, 7) == 7 { pass = pass + 1 }
	if math.MaxInt3(7, 7, 7) == 7 { pass = pass + 1 }

	// Two equal at the bound.
	if math.MinInt3(1, 1, 5) == 1 { pass = pass + 1 }
	if math.MaxInt3(1, 5, 5) == 5 { pass = pass + 1 }

	// Equivalent to MinInt2(a, MinInt2(b, c)).
	if math.MinInt3(8, 2, 5) == math.MinInt2(8, math.MinInt2(2, 5)) { pass = pass + 1 }
	if math.MaxInt3(8, 2, 5) == math.MaxInt2(8, math.MaxInt2(2, 5)) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
