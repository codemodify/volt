package main
import "log"
import "math"

// Positive test: math.NextMultipleOf + math.PrevMultipleOf.

fun main() int {
	var pass int = 0

	// NextMultipleOf basic.
	if math.NextMultipleOf(10, 4) == 12 { pass = pass + 1 }
	if math.NextMultipleOf(11, 4) == 12 { pass = pass + 1 }
	if math.NextMultipleOf(12, 4) == 12 { pass = pass + 1 }   // already multiple
	if math.NextMultipleOf(13, 4) == 16 { pass = pass + 1 }
	if math.NextMultipleOf(0, 4) == 0 { pass = pass + 1 }
	if math.NextMultipleOf(1, 4) == 4 { pass = pass + 1 }

	// NextMultipleOf with m=1 → identity.
	if math.NextMultipleOf(7, 1) == 7 { pass = pass + 1 }
	if math.NextMultipleOf(-3, 1) == -3 { pass = pass + 1 }

	// NextMultipleOf negative n.
	if math.NextMultipleOf(-10, 4) == -8 { pass = pass + 1 }
	if math.NextMultipleOf(-12, 4) == -12 { pass = pass + 1 }
	if math.NextMultipleOf(-1, 4) == 0 { pass = pass + 1 }

	// NextMultipleOf bad m.
	if math.NextMultipleOf(10, 0) == 0 { pass = pass + 1 }
	if math.NextMultipleOf(10, -3) == 0 { pass = pass + 1 }

	// PrevMultipleOf basic.
	if math.PrevMultipleOf(10, 4) == 8 { pass = pass + 1 }
	if math.PrevMultipleOf(11, 4) == 8 { pass = pass + 1 }
	if math.PrevMultipleOf(12, 4) == 12 { pass = pass + 1 }
	if math.PrevMultipleOf(15, 4) == 12 { pass = pass + 1 }
	if math.PrevMultipleOf(0, 4) == 0 { pass = pass + 1 }
	if math.PrevMultipleOf(1, 4) == 0 { pass = pass + 1 }

	// PrevMultipleOf negative.
	if math.PrevMultipleOf(-10, 4) == -12 { pass = pass + 1 }
	if math.PrevMultipleOf(-12, 4) == -12 { pass = pass + 1 }
	if math.PrevMultipleOf(-1, 4) == -4 { pass = pass + 1 }

	// PrevMultipleOf bad m.
	if math.PrevMultipleOf(10, 0) == 0 { pass = pass + 1 }
	if math.PrevMultipleOf(10, -3) == 0 { pass = pass + 1 }

	// Composition: Next - Prev gives 0 if aligned, else m.
	if (math.NextMultipleOf(10, 4) - math.PrevMultipleOf(10, 4)) == 4 { pass = pass + 1 }
	if (math.NextMultipleOf(12, 4) - math.PrevMultipleOf(12, 4)) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
