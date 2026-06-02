package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// WeekdayName — all 7.
	if time.WeekdayName(0) == "Sunday" { pass = pass + 1 }
	if time.WeekdayName(1) == "Monday" { pass = pass + 1 }
	if time.WeekdayName(2) == "Tuesday" { pass = pass + 1 }
	if time.WeekdayName(3) == "Wednesday" { pass = pass + 1 }
	if time.WeekdayName(4) == "Thursday" { pass = pass + 1 }
	if time.WeekdayName(5) == "Friday" { pass = pass + 1 }
	if time.WeekdayName(6) == "Saturday" { pass = pass + 1 }

	// WeekdayName — out-of-range.
	if time.WeekdayName(-1) == "" { pass = pass + 1 }
	if time.WeekdayName(7) == "" { pass = pass + 1 }
	if time.WeekdayName(100) == "" { pass = pass + 1 }

	// WeekdayAbbrev — all 7.
	if time.WeekdayAbbrev(0) == "Sun" { pass = pass + 1 }
	if time.WeekdayAbbrev(1) == "Mon" { pass = pass + 1 }
	if time.WeekdayAbbrev(2) == "Tue" { pass = pass + 1 }
	if time.WeekdayAbbrev(3) == "Wed" { pass = pass + 1 }
	if time.WeekdayAbbrev(4) == "Thu" { pass = pass + 1 }
	if time.WeekdayAbbrev(5) == "Fri" { pass = pass + 1 }
	if time.WeekdayAbbrev(6) == "Sat" { pass = pass + 1 }

	// WeekdayAbbrev — out-of-range.
	if time.WeekdayAbbrev(-1) == "" { pass = pass + 1 }
	if time.WeekdayAbbrev(7) == "" { pass = pass + 1 }

	// Consistency: free function matches method form (where available).
	var t time.Time = time.Date(2024, 6, 15, 0, 0, 0, 0)   // 2024-06-15 Saturday
	if time.WeekdayAbbrev(t.Weekday()) == t.WeekdayShortName() { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
