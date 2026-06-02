package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// DaysLeftInYear: Jan 1 in non-leap → 364.
	if time.DaysLeftInYear(time.Date(2026, 1, 1, 0, 0, 0, 0)) == 364 { pass = pass + 1 }

	// Jan 1 in leap → 365.
	if time.DaysLeftInYear(time.Date(2024, 1, 1, 0, 0, 0, 0)) == 365 { pass = pass + 1 }

	// Dec 31 → 0.
	if time.DaysLeftInYear(time.Date(2026, 12, 31, 0, 0, 0, 0)) == 0 { pass = pass + 1 }
	if time.DaysLeftInYear(time.Date(2024, 12, 31, 0, 0, 0, 0)) == 0 { pass = pass + 1 }

	// Dec 30 → 1.
	if time.DaysLeftInYear(time.Date(2026, 12, 30, 0, 0, 0, 0)) == 1 { pass = pass + 1 }

	// Mid-year (Jul 1 non-leap = day 182, leftover = 365-182 = 183).
	if time.DaysLeftInYear(time.Date(2026, 7, 1, 0, 0, 0, 0)) == 183 { pass = pass + 1 }

	// Cross-property: DayOfYear + DaysLeftInYear == DaysInYear.
	var t1 time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	var t1b time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	var t1c time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	if time.DayOfYear(t1) + time.DaysLeftInYear(t1b) == time.DaysInYear(t1c.Year()) { pass = pass + 1 }

	// In leap year too.
	var t2 time.Time = time.Date(2024, 5, 28, 0, 0, 0, 0)
	var t2b time.Time = time.Date(2024, 5, 28, 0, 0, 0, 0)
	if time.DayOfYear(t2) + time.DaysLeftInYear(t2b) == 366 { pass = pass + 1 }

	// DaysLeftInMonth: 1st of 31-day month → 30.
	if time.DaysLeftInMonth(time.Date(2026, 5, 1, 0, 0, 0, 0)) == 30 { pass = pass + 1 }

	// Last day of month → 0.
	if time.DaysLeftInMonth(time.Date(2026, 5, 31, 0, 0, 0, 0)) == 0 { pass = pass + 1 }
	if time.DaysLeftInMonth(time.Date(2026, 4, 30, 0, 0, 0, 0)) == 0 { pass = pass + 1 }

	// Mid-month.
	if time.DaysLeftInMonth(time.Date(2026, 5, 15, 0, 0, 0, 0)) == 16 { pass = pass + 1 }   // 31-15

	// February non-leap.
	if time.DaysLeftInMonth(time.Date(2026, 2, 28, 0, 0, 0, 0)) == 0 { pass = pass + 1 }
	if time.DaysLeftInMonth(time.Date(2026, 2, 1, 0, 0, 0, 0)) == 27 { pass = pass + 1 }

	// February leap.
	if time.DaysLeftInMonth(time.Date(2024, 2, 29, 0, 0, 0, 0)) == 0 { pass = pass + 1 }
	if time.DaysLeftInMonth(time.Date(2024, 2, 1, 0, 0, 0, 0)) == 28 { pass = pass + 1 }

	// Cross-property: t.Day() + DaysLeftInMonth(t) == DaysInMonth(y, m).
	var t3 time.Time = time.Date(2026, 5, 15, 0, 0, 0, 0)
	if t3.Day() + time.DaysLeftInMonth(t3) == time.DaysInMonth(2026, 5) { pass = pass + 1 }

	// Time-of-day doesn't affect.
	if time.DaysLeftInYear(time.Date(2026, 12, 30, 23, 59, 0, 0)) == 1 { pass = pass + 1 }
	if time.DaysLeftInMonth(time.Date(2026, 5, 30, 23, 59, 0, 0)) == 1 { pass = pass + 1 }

	// Use case: year progress percent (approx).
	var event time.Time = time.Date(2026, 4, 1, 0, 0, 0, 0)
	var doy int = time.DayOfYear(event)
	var event2 time.Time = time.Date(2026, 4, 1, 0, 0, 0, 0)
	var pct int = doy * 100 / time.DaysInYear(event2.Year())
	if pct >= 24 { pass = pass + 1 }   // April 1 is ~25% through year (≥24)

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
