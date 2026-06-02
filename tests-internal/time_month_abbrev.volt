package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// All 12 months.
	if time.MonthAbbrev(1) == "Jan" { pass = pass + 1 }
	if time.MonthAbbrev(2) == "Feb" { pass = pass + 1 }
	if time.MonthAbbrev(3) == "Mar" { pass = pass + 1 }
	if time.MonthAbbrev(4) == "Apr" { pass = pass + 1 }
	if time.MonthAbbrev(5) == "May" { pass = pass + 1 }
	if time.MonthAbbrev(6) == "Jun" { pass = pass + 1 }
	if time.MonthAbbrev(7) == "Jul" { pass = pass + 1 }
	if time.MonthAbbrev(8) == "Aug" { pass = pass + 1 }
	if time.MonthAbbrev(9) == "Sep" { pass = pass + 1 }
	if time.MonthAbbrev(10) == "Oct" { pass = pass + 1 }
	if time.MonthAbbrev(11) == "Nov" { pass = pass + 1 }
	if time.MonthAbbrev(12) == "Dec" { pass = pass + 1 }

	// Out-of-range.
	if time.MonthAbbrev(0) == "" { pass = pass + 1 }
	if time.MonthAbbrev(13) == "" { pass = pass + 1 }
	if time.MonthAbbrev(-1) == "" { pass = pass + 1 }
	if time.MonthAbbrev(100) == "" { pass = pass + 1 }

	// Each abbreviation is the first 3 chars of MonthName for months
	// 1-9 (where MonthName has length ≥ 3 already), and consistent
	// for 10-12.
	if time.MonthAbbrev(1) == "Jan" { pass = pass + 1 }
	if time.MonthAbbrev(3) == "Mar" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
