package main
import "log"
import "time"

// Positive test: time.AddDate(years, months, days). Civil-calendar
// shift with month overflow normalized into year carry.

fun main() int {
	var pass int = 0

	// Add 1 day.
	var t1 time.Time = time.Date(2024, 3, 15, 12, 30, 45, 0)
	var t1b time.Time = t1.AddDate(0, 0, 1)
	if t1b.DateString() == "2024-03-16" { pass = pass + 1 }
	if t1b.Hour() == 12 { pass = pass + 1 }    // time-of-day preserved
	if t1b.Minute() == 30 { pass = pass + 1 }

	// Add 1 month.
	var t2 time.Time = time.Date(2024, 3, 15, 0, 0, 0, 0)
	var t2b time.Time = t2.AddDate(0, 1, 0)
	if t2b.DateString() == "2024-04-15" { pass = pass + 1 }

	// Add 1 year.
	var t3 time.Time = time.Date(2024, 3, 15, 0, 0, 0, 0)
	var t3b time.Time = t3.AddDate(1, 0, 0)
	if t3b.DateString() == "2025-03-15" { pass = pass + 1 }

	// Month overflow: Dec + 2 months → Feb next year.
	var t4 time.Time = time.Date(2024, 12, 31, 0, 0, 0, 0)
	var t4b time.Time = t4.AddDate(0, 2, 0)
	if t4b.Year() == 2025 { pass = pass + 1 }
	// d=31, m=2 → daysFromCivil normalizes 2025-02-31 → 2025-03-03
	if t4b.Month() == 3 { pass = pass + 1 }

	// Negative day: yesterday.
	var t5 time.Time = time.Date(2024, 3, 1, 0, 0, 0, 0)
	var t5b time.Time = t5.AddDate(0, 0, -1)
	if t5b.DateString() == "2024-02-29" { pass = pass + 1 }   // leap-year Feb

	// Negative year + negative month.
	var t6 time.Time = time.Date(2024, 3, 15, 0, 0, 0, 0)
	var t6b time.Time = t6.AddDate(-1, -2, 0)
	if t6b.Year() == 2023 { pass = pass + 1 }
	if t6b.Month() == 1 { pass = pass + 1 }

	// Add a large number of days (overflow into year).
	var t7 time.Time = time.Date(2024, 1, 1, 0, 0, 0, 0)
	var t7b time.Time = t7.AddDate(0, 0, 366)   // 2024 is a leap year
	if t7b.DateString() == "2025-01-01" { pass = pass + 1 }

	// AddDate(0, 0, 0) is identity.
	var t8 time.Time = time.Date(2024, 6, 15, 12, 30, 45, 0)
	var t8b time.Time = t8.AddDate(0, 0, 0)
	if t8b.Format() == "2024-06-15T12:30:45Z" { pass = pass + 1 }

	log.Println("pass=%d t1b=%s t5b=%s", pass, t1b.DateString(), t5b.DateString())
	if pass == 12 { ret 42 }
	ret 0
}
