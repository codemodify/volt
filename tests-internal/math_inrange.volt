package main
import "log"
import "math"

fun main() int {
	var pass int = 0

	// In range.
	if math.InRange(5, 0, 10) { pass = pass + 1 }
	if math.InRange(0, 0, 10) { pass = pass + 1 }    // lo boundary
	if math.InRange(10, 0, 10) { pass = pass + 1 }   // hi boundary

	// Outside.
	if !math.InRange(-1, 0, 10) { pass = pass + 1 }
	if !math.InRange(11, 0, 10) { pass = pass + 1 }

	// Negative range.
	if math.InRange(-5, -10, -1) { pass = pass + 1 }
	if math.InRange(-10, -10, -1) { pass = pass + 1 }
	if math.InRange(-1, -10, -1) { pass = pass + 1 }
	if !math.InRange(0, -10, -1) { pass = pass + 1 }
	if !math.InRange(-11, -10, -1) { pass = pass + 1 }

	// Single-value range.
	if math.InRange(5, 5, 5) { pass = pass + 1 }
	if !math.InRange(4, 5, 5) { pass = pass + 1 }
	if !math.InRange(6, 5, 5) { pass = pass + 1 }

	// Degenerate range (lo > hi).
	if !math.InRange(5, 10, 0) { pass = pass + 1 }
	if !math.InRange(5, 5, 4) { pass = pass + 1 }

	// Cross-property: ClampInt(v, lo, hi) is in range [lo, hi].
	var c1 int = math.ClampInt(-5, 0, 10)
	if math.InRange(c1, 0, 10) { pass = pass + 1 }
	var c2 int = math.ClampInt(15, 0, 10)
	if math.InRange(c2, 0, 10) { pass = pass + 1 }
	var c3 int = math.ClampInt(7, 0, 10)
	if math.InRange(c3, 0, 10) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
