package main
import "log"
import "time"

// Test the new top-level time.IsWeekend / time.IsWeekday functions
// (companion to the existing (t Time).IsWeekend / IsWeekday methods).

fun main() int {
	var pass int = 0

	// 2026-05-30 is a Saturday.
	var sat time.Time = time.Date(2026, 5, 30, 12, 0, 0, 0)
	if time.IsWeekend(sat) { pass = pass + 1 }
	var sat2 time.Time = time.Date(2026, 5, 30, 12, 0, 0, 0)
	if !time.IsWeekday(sat2) { pass = pass + 1 }

	// 2026-05-31 is a Sunday.
	var sun time.Time = time.Date(2026, 5, 31, 12, 0, 0, 0)
	if time.IsWeekend(sun) { pass = pass + 1 }
	var sun2 time.Time = time.Date(2026, 5, 31, 12, 0, 0, 0)
	if !time.IsWeekday(sun2) { pass = pass + 1 }

	// 2026-05-28 is a Thursday.
	var thu time.Time = time.Date(2026, 5, 28, 12, 0, 0, 0)
	if !time.IsWeekend(thu) { pass = pass + 1 }
	var thu2 time.Time = time.Date(2026, 5, 28, 12, 0, 0, 0)
	if time.IsWeekday(thu2) { pass = pass + 1 }

	// 2026-06-01 is a Monday.
	var mon time.Time = time.Date(2026, 6, 1, 0, 0, 0, 0)
	if time.IsWeekday(mon) { pass = pass + 1 }
	var mon2 time.Time = time.Date(2026, 6, 1, 0, 0, 0, 0)
	if !time.IsWeekend(mon2) { pass = pass + 1 }

	// 2026-05-29 is a Friday.
	var fri time.Time = time.Date(2026, 5, 29, 0, 0, 0, 0)
	if time.IsWeekday(fri) { pass = pass + 1 }
	var fri2 time.Time = time.Date(2026, 5, 29, 0, 0, 0, 0)
	if !time.IsWeekend(fri2) { pass = pass + 1 }

	// XOR cross-property: IsWeekend != IsWeekday always.
	var t1 time.Time = time.Date(2026, 6, 2, 0, 0, 0, 0)
	var t1b time.Time = time.Date(2026, 6, 2, 0, 0, 0, 0)
	if time.IsWeekend(t1) != time.IsWeekday(t1b) { pass = pass + 1 }

	// Equivalence with method form.
	var t2 time.Time = time.Date(2026, 5, 30, 0, 0, 0, 0)
	var t2b time.Time = time.Date(2026, 5, 30, 0, 0, 0, 0)
	if time.IsWeekend(t2) == t2b.IsWeekend() { pass = pass + 1 }

	// Time-of-day ignored.
	var sat3 time.Time = time.Date(2026, 5, 30, 23, 59, 59, 0)
	if time.IsWeekend(sat3) { pass = pass + 1 }

	// Walk a week: 7 consecutive days have 2 weekends + 5 weekdays.
	var weekendCount int = 0
	var weekdayCount int = 0
	for i := 0; i < 7; i++ {
		var d time.Time = time.Date(2026, 5, 25 + i, 0, 0, 0, 0)   // Mon May 25 onward
		if time.IsWeekend(d) { weekendCount = weekendCount + 1 }
		if time.IsWeekday(d) { weekdayCount = weekdayCount + 1 }
	}
	if weekendCount == 2 { pass = pass + 1 }
	if weekdayCount == 5 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
