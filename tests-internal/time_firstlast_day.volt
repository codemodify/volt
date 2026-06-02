package main
import "log"
import "time"

// Positive test: (t Time).IsFirstDayOfMonth + IsFirstDayOfYear + IsLastDayOfYear.

fun main() int {
	var pass int = 0

	// IsFirstDayOfMonth — day 1 of various months.
	if time.Date(2024, 1, 1, 0, 0, 0, 0).IsFirstDayOfMonth() { pass = pass + 1 }
	if time.Date(2024, 3, 1, 12, 0, 0, 0).IsFirstDayOfMonth() { pass = pass + 1 }
	if time.Date(2024, 12, 1, 23, 59, 59, 0).IsFirstDayOfMonth() { pass = pass + 1 }

	// Not first day.
	if !time.Date(2024, 1, 2, 0, 0, 0, 0).IsFirstDayOfMonth() { pass = pass + 1 }
	if !time.Date(2024, 3, 31, 0, 0, 0, 0).IsFirstDayOfMonth() { pass = pass + 1 }
	if !time.Date(2024, 12, 15, 0, 0, 0, 0).IsFirstDayOfMonth() { pass = pass + 1 }

	// IsFirstDayOfYear — Jan 1.
	if time.Date(2024, 1, 1, 0, 0, 0, 0).IsFirstDayOfYear() { pass = pass + 1 }
	if time.Date(2025, 1, 1, 12, 0, 0, 0).IsFirstDayOfYear() { pass = pass + 1 }
	if time.Date(1970, 1, 1, 0, 0, 0, 0).IsFirstDayOfYear() { pass = pass + 1 }   // epoch

	// Not Jan 1.
	if !time.Date(2024, 1, 2, 0, 0, 0, 0).IsFirstDayOfYear() { pass = pass + 1 }
	if !time.Date(2024, 2, 1, 0, 0, 0, 0).IsFirstDayOfYear() { pass = pass + 1 }   // day 1 of Feb
	if !time.Date(2024, 12, 31, 0, 0, 0, 0).IsFirstDayOfYear() { pass = pass + 1 }

	// IsLastDayOfYear — Dec 31.
	if time.Date(2024, 12, 31, 0, 0, 0, 0).IsLastDayOfYear() { pass = pass + 1 }
	if time.Date(2025, 12, 31, 23, 59, 59, 999999999).IsLastDayOfYear() { pass = pass + 1 }
	if time.Date(1999, 12, 31, 12, 0, 0, 0).IsLastDayOfYear() { pass = pass + 1 }

	// Not Dec 31.
	if !time.Date(2024, 12, 30, 0, 0, 0, 0).IsLastDayOfYear() { pass = pass + 1 }
	if !time.Date(2024, 1, 31, 0, 0, 0, 0).IsLastDayOfYear() { pass = pass + 1 }   // last day of Jan
	if !time.Date(2024, 11, 30, 0, 0, 0, 0).IsLastDayOfYear() { pass = pass + 1 }   // last day of Nov

	// First day of month coincides with first day of year for Jan 1.
	var jan1 time.Time = time.Date(2024, 1, 1, 0, 0, 0, 0)
	if jan1.IsFirstDayOfMonth() {
		if jan1.IsFirstDayOfYear() { pass = pass + 1 }
	}

	// Symmetric Last invariants: last-of-month and last-of-year coincide for Dec 31.
	var dec31 time.Time = time.Date(2024, 12, 31, 0, 0, 0, 0)
	if dec31.IsLastDayOfMonth() {
		if dec31.IsLastDayOfYear() { pass = pass + 1 }
	}

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
