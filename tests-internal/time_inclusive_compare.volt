package main
import "log"
import "time"

// Positive test: (t Time).IsAtOrBefore + IsAtOrAfter + Min + Max.

fun main() int {
	var pass int = 0

	var t1 time.Time = time.Date(2024, 3, 15, 12, 0, 0, 0)
	var t2 time.Time = time.Date(2024, 3, 15, 12, 0, 0, 0)
	var t3 time.Time = time.Date(2024, 3, 16, 12, 0, 0, 0)

	// IsAtOrBefore — equal.
	if t1.IsAtOrBefore(t2) { pass = pass + 1 }
	// IsAtOrBefore — earlier.
	if t1.IsAtOrBefore(t3) { pass = pass + 1 }
	// IsAtOrBefore — later returns false.
	if !t3.IsAtOrBefore(t1) { pass = pass + 1 }

	// IsAtOrAfter — equal.
	if t1.IsAtOrAfter(t2) { pass = pass + 1 }
	// IsAtOrAfter — later.
	if t3.IsAtOrAfter(t1) { pass = pass + 1 }
	// IsAtOrAfter — earlier returns false.
	if !t1.IsAtOrAfter(t3) { pass = pass + 1 }

	// Min — t1 earlier.
	var m1 time.Time = t1.Min(t3)
	if m1.Equal(t1) { pass = pass + 1 }
	// Min — receiver later.
	var m2 time.Time = t3.Min(t1)
	if m2.Equal(t1) { pass = pass + 1 }
	// Min — equal → receiver.
	var m3 time.Time = t1.Min(t2)
	if m3.Equal(t1) { pass = pass + 1 }

	// Max — t3 later.
	var x1 time.Time = t1.Max(t3)
	if x1.Equal(t3) { pass = pass + 1 }
	// Max — receiver later.
	var x2 time.Time = t3.Max(t1)
	if x2.Equal(t3) { pass = pass + 1 }
	// Max — equal → receiver.
	var x3 time.Time = t1.Max(t2)
	if x3.Equal(t1) { pass = pass + 1 }

	// Composite: clamp a candidate to [floor, ceil].
	var floor time.Time = time.Date(2024, 3, 10, 0, 0, 0, 0)
	var ceil time.Time = time.Date(2024, 3, 20, 0, 0, 0, 0)
	var early time.Time = time.Date(2024, 3, 1, 0, 0, 0, 0)
	var late time.Time = time.Date(2024, 4, 1, 0, 0, 0, 0)
	var inside time.Time = time.Date(2024, 3, 15, 0, 0, 0, 0)

	var clampedEarly time.Time = early.Max(floor).Min(ceil)
	if clampedEarly.Equal(floor) { pass = pass + 1 }

	var clampedLate time.Time = late.Max(floor).Min(ceil)
	if clampedLate.Equal(ceil) { pass = pass + 1 }

	var clampedInside time.Time = inside.Max(floor).Min(ceil)
	if clampedInside.Equal(inside) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
