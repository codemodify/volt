package main
import "log"
import "time"

// Positive test: (t Time).DaysBetween(u).

fun main() int {
	var pass int = 0

	// Same date → 0.
	var t1 time.Time = time.Date(2024, 3, 15, 12, 0, 0, 0)
	var t2 time.Time = time.Date(2024, 3, 15, 12, 0, 0, 0)
	if t1.DaysBetween(t2) == 0 { pass = pass + 1 }

	// One day later.
	var t3 time.Time = time.Date(2024, 3, 16, 0, 0, 0, 0)
	if t3.DaysBetween(t1) == 1 { pass = pass + 1 }

	// One day earlier → -1.
	var t4 time.Time = time.Date(2024, 3, 14, 0, 0, 0, 0)
	if t4.DaysBetween(t1) == -1 { pass = pass + 1 }

	// Across a month.
	var t5 time.Time = time.Date(2024, 4, 15, 0, 0, 0, 0)
	if t5.DaysBetween(t1) == 31 { pass = pass + 1 }   // March has 31 days

	// Across a year.
	var t6 time.Time = time.Date(2025, 3, 15, 0, 0, 0, 0)
	if t6.DaysBetween(t1) == 365 { pass = pass + 1 }   // 2024 → 2025 = 365 days (Mar 15 → Mar 15)

	// Through a leap day.
	var feb1 time.Time = time.Date(2024, 2, 1, 0, 0, 0, 0)
	var mar1 time.Time = time.Date(2024, 3, 1, 0, 0, 0, 0)
	if mar1.DaysBetween(feb1) == 29 { pass = pass + 1 }   // 2024 is leap year

	// Non-leap year Feb→Mar.
	var feb1_23 time.Time = time.Date(2023, 2, 1, 0, 0, 0, 0)
	var mar1_23 time.Time = time.Date(2023, 3, 1, 0, 0, 0, 0)
	if mar1_23.DaysBetween(feb1_23) == 28 { pass = pass + 1 }

	// Time-of-day ignored — same day, different hours.
	var morning time.Time = time.Date(2024, 3, 15, 1, 0, 0, 0)
	var evening time.Time = time.Date(2024, 3, 15, 23, 0, 0, 0)
	if evening.DaysBetween(morning) == 0 { pass = pass + 1 }

	// Epoch ↔ epoch+1 day.
	var t7 time.Time = time.FromNano(0)
	var t8 time.Time = time.Date(1970, 1, 2, 0, 0, 0, 0)
	if t8.DaysBetween(t7) == 1 { pass = pass + 1 }

	// Symmetric: a.DaysBetween(b) == -b.DaysBetween(a).
	if t1.DaysBetween(t3) == -1 { pass = pass + 1 }
	if t1.DaysBetween(t5) == -31 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 11 { ret 42 }
	ret 0
}
