package main
import "log"
import "time"

// Positive test: (t Time).StartOfQuarter + EndOfQuarter.

fun main() int {
	var pass int = 0

	// Q1 from Feb 15 → Jan 1 .. Mar 31.
	var q1mid time.Time = time.Date(2024, 2, 15, 12, 0, 0, 0)
	var q1s time.Time = q1mid.StartOfQuarter()
	var q1e time.Time = q1mid.EndOfQuarter()
	if q1s.Month() == 1 { pass = pass + 1 }
	if q1s.Day() == 1 { pass = pass + 1 }
	if q1s.Hour() == 0 { pass = pass + 1 }
	if q1e.Month() == 3 { pass = pass + 1 }
	if q1e.Day() == 31 { pass = pass + 1 }
	if q1e.Hour() == 23 { pass = pass + 1 }

	// Q2 from May 10 → Apr 1 .. Jun 30.
	var q2mid time.Time = time.Date(2024, 5, 10, 0, 0, 0, 0)
	var q2s time.Time = q2mid.StartOfQuarter()
	var q2e time.Time = q2mid.EndOfQuarter()
	if q2s.Month() == 4 { pass = pass + 1 }
	if q2s.Day() == 1 { pass = pass + 1 }
	if q2e.Month() == 6 { pass = pass + 1 }
	if q2e.Day() == 30 { pass = pass + 1 }

	// Q3 from Aug 1 → Jul 1 .. Sep 30.
	var q3mid time.Time = time.Date(2024, 8, 1, 0, 0, 0, 0)
	var q3s time.Time = q3mid.StartOfQuarter()
	var q3e time.Time = q3mid.EndOfQuarter()
	if q3s.Month() == 7 { pass = pass + 1 }
	if q3e.Month() == 9 { pass = pass + 1 }
	if q3e.Day() == 30 { pass = pass + 1 }

	// Q4 from Nov 15 → Oct 1 .. Dec 31.
	var q4mid time.Time = time.Date(2024, 11, 15, 0, 0, 0, 0)
	var q4s time.Time = q4mid.StartOfQuarter()
	var q4e time.Time = q4mid.EndOfQuarter()
	if q4s.Month() == 10 { pass = pass + 1 }
	if q4e.Month() == 12 { pass = pass + 1 }
	if q4e.Day() == 31 { pass = pass + 1 }

	// StartOfQuarter on the first day = identity (modulo time-of-day).
	var jan1 time.Time = time.Date(2024, 1, 1, 12, 0, 0, 0)
	var sj time.Time = jan1.StartOfQuarter()
	if sj.Day() == 1 { pass = pass + 1 }
	if sj.Month() == 1 { pass = pass + 1 }
	if sj.Hour() == 0 { pass = pass + 1 }

	// Year preserved.
	var t2025 time.Time = time.Date(2025, 7, 15, 0, 0, 0, 0)
	if t2025.StartOfQuarter().Year() == 2025 { pass = pass + 1 }
	if t2025.EndOfQuarter().Year() == 2025 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
