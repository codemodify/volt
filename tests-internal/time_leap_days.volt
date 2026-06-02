package main
import "log"
import "time"

// Positive test: time.IsLeapYear + time.DaysInMonth — Gregorian
// calendar utilities.

fun main() int {
	var pass int = 0

	// Standard leap-year rules.
	if time.IsLeapYear(2024) { pass = pass + 1 }       // div by 4
	if !time.IsLeapYear(2023) { pass = pass + 1 }      // not
	if !time.IsLeapYear(1900) { pass = pass + 1 }      // century not div 400
	if time.IsLeapYear(2000) { pass = pass + 1 }       // century div 400
	if time.IsLeapYear(1600) { pass = pass + 1 }
	if !time.IsLeapYear(1700) { pass = pass + 1 }
	if time.IsLeapYear(4) { pass = pass + 1 }          // far past
	if time.IsLeapYear(0) { pass = pass + 1 }          // year 0: div by 400 → leap

	// Days in month — common months.
	if time.DaysInMonth(2024, 1) == 31 { pass = pass + 1 }
	if time.DaysInMonth(2024, 2) == 29 { pass = pass + 1 }   // leap year
	if time.DaysInMonth(2023, 2) == 28 { pass = pass + 1 }   // non-leap
	if time.DaysInMonth(2024, 4) == 30 { pass = pass + 1 }
	if time.DaysInMonth(2024, 12) == 31 { pass = pass + 1 }

	// February century edge cases.
	if time.DaysInMonth(1900, 2) == 28 { pass = pass + 1 }   // century, not leap
	if time.DaysInMonth(2000, 2) == 29 { pass = pass + 1 }   // century, leap

	// Out-of-range month → 0.
	if time.DaysInMonth(2024, 0) == 0 { pass = pass + 1 }
	if time.DaysInMonth(2024, 13) == 0 { pass = pass + 1 }
	if time.DaysInMonth(2024, -1) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
