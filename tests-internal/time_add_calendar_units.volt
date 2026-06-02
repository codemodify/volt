package main
import "log"
import "time"

// Positive test: (t Time).AddDays + AddWeeks + AddMonths + AddYears.

fun main() int {
	var pass int = 0

	var base time.Time = time.Date(2024, 6, 15, 10, 30, 0, 0)

	// AddDays.
	var d1 time.Time = base.AddDays(1)
	if d1.Day() == 16 { pass = pass + 1 }
	if d1.Hour() == 10 { pass = pass + 1 }     // wall-clock preserved

	var d30 time.Time = base.AddDays(30)
	if d30.Month() == 7 { pass = pass + 1 }
	if d30.Day() == 15 { pass = pass + 1 }

	// AddDays — negative.
	var dm5 time.Time = base.AddDays(-5)
	if dm5.Day() == 10 { pass = pass + 1 }

	// AddWeeks — basic.
	var w1 time.Time = base.AddWeeks(1)
	if w1.Day() == 22 { pass = pass + 1 }

	var w4 time.Time = base.AddWeeks(4)
	if w4.Month() == 7 { pass = pass + 1 }
	if w4.Day() == 13 { pass = pass + 1 }

	// AddWeeks — negative.
	var wm2 time.Time = base.AddWeeks(-2)
	if wm2.Month() == 6 { pass = pass + 1 }
	if wm2.Day() == 1 { pass = pass + 1 }

	// AddMonths — basic.
	var m1 time.Time = base.AddMonths(1)
	if m1.Month() == 7 { pass = pass + 1 }
	if m1.Day() == 15 { pass = pass + 1 }

	var m6 time.Time = base.AddMonths(6)
	if m6.Year() == 2024 { pass = pass + 1 }
	if m6.Month() == 12 { pass = pass + 1 }

	// AddMonths — day overflow on shorter target month spills forward
	// (Jan 31 + 1 month = "Feb 31" → resolved to early March, not clamped).
	var jan31 time.Time = time.Date(2024, 1, 31, 0, 0, 0, 0)
	var feb time.Time = jan31.AddMonths(1)
	if feb.Month() == 3 { pass = pass + 1 }

	// AddMonths — wraps to next year.
	var jul time.Time = time.Date(2024, 7, 1, 0, 0, 0, 0)
	var nextJan time.Time = jul.AddMonths(6)
	if nextJan.Year() == 2025 { pass = pass + 1 }
	if nextJan.Month() == 1 { pass = pass + 1 }

	// AddYears — basic.
	var y1 time.Time = base.AddYears(1)
	if y1.Year() == 2025 { pass = pass + 1 }
	if y1.Month() == 6 { pass = pass + 1 }
	if y1.Day() == 15 { pass = pass + 1 }

	// AddYears — Feb 29 on a non-leap year overflows forward to Mar 1
	// (no clamping; Hinnant's algorithm resolves the invalid date by
	// counting days).
	var leap time.Time = time.Date(2024, 2, 29, 0, 0, 0, 0)
	var nonLeap time.Time = leap.AddYears(1)
	if nonLeap.Year() == 2025 { pass = pass + 1 }
	if nonLeap.Month() == 3 { pass = pass + 1 }
	if nonLeap.Day() == 1 { pass = pass + 1 }

	// Identity: AddDays(7) == AddWeeks(1).
	if base.AddDays(7).Sub(base.AddWeeks(1)) == 0 { pass = pass + 1 }

	// AddYears(-1).
	var y2023 time.Time = base.AddYears(-1)
	if y2023.Year() == 2023 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 25 { ret 42 }
	ret 0
}
