package main
import "log"
import "math"
import "time"

// Positive test: math.MapRange + (t Time).DayOfQuarter.

fun main() int {
	var pass int = 0

	// MapRange endpoints.
	if math.MapRange(0, 0, 100, 0, 1000) == 0 { pass = pass + 1 }
	if math.MapRange(100, 0, 100, 0, 1000) == 1000 { pass = pass + 1 }

	// MapRange interior.
	if math.MapRange(50, 0, 100, 0, 1000) == 500 { pass = pass + 1 }
	if math.MapRange(25, 0, 100, 0, 1000) == 250 { pass = pass + 1 }

	// MapRange non-zero source range.
	if math.MapRange(15, 10, 20, 0, 100) == 50 { pass = pass + 1 }

	// MapRange inverted destination.
	if math.MapRange(0, 0, 100, 100, 0) == 100 { pass = pass + 1 }
	if math.MapRange(100, 0, 100, 100, 0) == 0 { pass = pass + 1 }

	// MapRange negative ranges.
	if math.MapRange(0, -10, 10, 0, 100) == 50 { pass = pass + 1 }

	// MapRange degenerate source.
	if math.MapRange(5, 10, 10, 0, 100) == 0 { pass = pass + 1 }

	// MapRange extrapolation.
	if math.MapRange(150, 0, 100, 0, 1000) == 1500 { pass = pass + 1 }
	if math.MapRange(-25, 0, 100, 0, 1000) == -250 { pass = pass + 1 }

	// DayOfQuarter — Jan 1 is day 1 of Q1.
	if time.Date(2024, 1, 1, 0, 0, 0, 0).DayOfQuarter() == 1 { pass = pass + 1 }
	// Feb 1 — Q1 day 32 (Jan has 31 days).
	if time.Date(2024, 2, 1, 0, 0, 0, 0).DayOfQuarter() == 32 { pass = pass + 1 }
	// Mar 1 — Q1 day 61 (31 + 29 leap).
	if time.Date(2024, 3, 1, 0, 0, 0, 0).DayOfQuarter() == 61 { pass = pass + 1 }
	// Mar 31 — last day of Q1 = 91 days (31+29+31).
	if time.Date(2024, 3, 31, 0, 0, 0, 0).DayOfQuarter() == 91 { pass = pass + 1 }
	// Mar 31 non-leap year — Q1 has 90 days (31+28+31).
	if time.Date(2023, 3, 31, 0, 0, 0, 0).DayOfQuarter() == 90 { pass = pass + 1 }
	// Apr 1 — Q2 day 1.
	if time.Date(2024, 4, 1, 0, 0, 0, 0).DayOfQuarter() == 1 { pass = pass + 1 }
	// Jun 30 — Q2 day 91 (30+31+30).
	if time.Date(2024, 6, 30, 0, 0, 0, 0).DayOfQuarter() == 91 { pass = pass + 1 }
	// Jul 1 — Q3 day 1.
	if time.Date(2024, 7, 1, 0, 0, 0, 0).DayOfQuarter() == 1 { pass = pass + 1 }
	// Sep 30 — Q3 day 92 (31+31+30).
	if time.Date(2024, 9, 30, 0, 0, 0, 0).DayOfQuarter() == 92 { pass = pass + 1 }
	// Oct 1 — Q4 day 1.
	if time.Date(2024, 10, 1, 0, 0, 0, 0).DayOfQuarter() == 1 { pass = pass + 1 }
	// Dec 31 — Q4 last day = 92 (31+30+31).
	if time.Date(2024, 12, 31, 0, 0, 0, 0).DayOfQuarter() == 92 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
