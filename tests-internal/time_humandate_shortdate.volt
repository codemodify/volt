package main
import "log"
import "time"

// Positive test: (t Time).HumanDate + ShortDate.

fun main() int {
	var pass int = 0

	// 2024-06-15 is Saturday.
	var t1 time.Time = time.Date(2024, 6, 15, 12, 0, 0, 0)
	if t1.HumanDate() == "Saturday, June 15, 2024" { pass = pass + 1 }
	if t1.ShortDate() == "Jun 15, 2024" { pass = pass + 1 }

	// 2024-01-01 is Monday.
	var newYear time.Time = time.Date(2024, 1, 1, 0, 0, 0, 0)
	if newYear.HumanDate() == "Monday, January 1, 2024" { pass = pass + 1 }
	if newYear.ShortDate() == "Jan 1, 2024" { pass = pass + 1 }

	// 2024-12-31 is Tuesday.
	var newYearEve time.Time = time.Date(2024, 12, 31, 23, 59, 0, 0)
	if newYearEve.HumanDate() == "Tuesday, December 31, 2024" { pass = pass + 1 }
	if newYearEve.ShortDate() == "Dec 31, 2024" { pass = pass + 1 }

	// 2024-02-29 leap day = Thursday.
	var leapDay time.Time = time.Date(2024, 2, 29, 12, 0, 0, 0)
	if leapDay.HumanDate() == "Thursday, February 29, 2024" { pass = pass + 1 }
	if leapDay.ShortDate() == "Feb 29, 2024" { pass = pass + 1 }

	// Day-1 single-digit doesn't get padded.
	var jan5 time.Time = time.Date(2024, 1, 5, 0, 0, 0, 0)
	if jan5.HumanDate() == "Friday, January 5, 2024" { pass = pass + 1 }
	if jan5.ShortDate() == "Jan 5, 2024" { pass = pass + 1 }

	// Each month name appears (smoke check across 12 months).
	var mar time.Time = time.Date(2024, 3, 10, 0, 0, 0, 0)
	if mar.ShortDate() == "Mar 10, 2024" { pass = pass + 1 }
	var apr time.Time = time.Date(2024, 4, 10, 0, 0, 0, 0)
	if apr.ShortDate() == "Apr 10, 2024" { pass = pass + 1 }
	var may time.Time = time.Date(2024, 5, 10, 0, 0, 0, 0)
	if may.ShortDate() == "May 10, 2024" { pass = pass + 1 }

	// Time-of-day doesn't appear in either output.
	var withTime time.Time = time.Date(2024, 6, 15, 23, 59, 59, 999999999)
	if withTime.HumanDate() == "Saturday, June 15, 2024" { pass = pass + 1 }
	if withTime.ShortDate() == "Jun 15, 2024" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
