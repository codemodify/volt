package main
import "log"
import "time"
import "math"

// Positive test: (t Time).IsBetween + math.IsArmstrong.

fun main() int {
	var pass int = 0

	var lo time.Time = time.Date(2024, 3, 1, 0, 0, 0, 0)
	var hi time.Time = time.Date(2024, 3, 31, 23, 59, 59, 0)

	// Inside the window.
	var inside time.Time = time.Date(2024, 3, 15, 12, 0, 0, 0)
	if inside.IsBetween(lo, hi) { pass = pass + 1 }

	// At the lower bound (inclusive).
	if lo.IsBetween(lo, hi) { pass = pass + 1 }

	// At the upper bound (inclusive).
	if hi.IsBetween(lo, hi) { pass = pass + 1 }

	// Below the lower bound.
	var early time.Time = time.Date(2024, 2, 28, 12, 0, 0, 0)
	if !early.IsBetween(lo, hi) { pass = pass + 1 }

	// Above the upper bound.
	var late time.Time = time.Date(2024, 4, 1, 0, 0, 0, 0)
	if !late.IsBetween(lo, hi) { pass = pass + 1 }

	// Degenerate window (lo > hi).
	if !inside.IsBetween(hi, lo) { pass = pass + 1 }

	// Single-instant window (lo == hi == t).
	if inside.IsBetween(inside, inside) { pass = pass + 1 }

	// Just outside by one nanosecond on each side.
	var nsBefore time.Time = time.FromNano(lo.UnixNano() - 1)
	if !nsBefore.IsBetween(lo, hi) { pass = pass + 1 }
	var nsAfter time.Time = time.FromNano(hi.UnixNano() + 1)
	if !nsAfter.IsBetween(lo, hi) { pass = pass + 1 }

	// IsArmstrong — small examples.
	if math.IsArmstrong(0) { pass = pass + 1 }    // 0^1 = 0
	if math.IsArmstrong(1) { pass = pass + 1 }
	if math.IsArmstrong(2) { pass = pass + 1 }
	if math.IsArmstrong(9) { pass = pass + 1 }

	// IsArmstrong — known 3-digit.
	if math.IsArmstrong(153) { pass = pass + 1 }    // 1+125+27 = 153
	if math.IsArmstrong(370) { pass = pass + 1 }
	if math.IsArmstrong(371) { pass = pass + 1 }
	if math.IsArmstrong(407) { pass = pass + 1 }

	// IsArmstrong — known 4-digit.
	if math.IsArmstrong(1634) { pass = pass + 1 }
	if math.IsArmstrong(8208) { pass = pass + 1 }
	if math.IsArmstrong(9474) { pass = pass + 1 }

	// Not Armstrong.
	if !math.IsArmstrong(10) { pass = pass + 1 }
	if !math.IsArmstrong(100) { pass = pass + 1 }
	if !math.IsArmstrong(152) { pass = pass + 1 }
	if !math.IsArmstrong(1000) { pass = pass + 1 }

	// Negatives.
	if !math.IsArmstrong(-153) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 25 { ret 42 }
	ret 0
}
