package main
import "log"
import "time"

// Positive test: (t Time).Weekday() + WeekdayName(). Jan 1 1970 is
// a Thursday → epoch Weekday() = 4 / WeekdayName() = "Thursday".

fun main() int {
	var pass int = 0

	// Epoch is a Thursday.
	var t0 time.Time = time.Date(1970, 1, 1, 0, 0, 0, 0)
	if t0.Weekday() == 4 { pass = pass + 1 }
	if t0.WeekdayName() == "Thursday" { pass = pass + 1 }

	// Jan 2 1970 = Friday.
	var t1 time.Time = time.Date(1970, 1, 2, 0, 0, 0, 0)
	if t1.Weekday() == 5 { pass = pass + 1 }
	if t1.WeekdayName() == "Friday" { pass = pass + 1 }

	// Cross-check: 2024-03-15 was a Friday.
	var t2 time.Time = time.Date(2024, 3, 15, 12, 0, 0, 0)
	if t2.Weekday() == 5 { pass = pass + 1 }
	if t2.WeekdayName() == "Friday" { pass = pass + 1 }

	// 2024-05-26 was a Sunday.
	var t3 time.Time = time.Date(2024, 5, 26, 0, 0, 0, 0)
	if t3.Weekday() == 0 { pass = pass + 1 }
	if t3.WeekdayName() == "Sunday" { pass = pass + 1 }

	// 2024-12-31 was a Tuesday.
	var t4 time.Time = time.Date(2024, 12, 31, 0, 0, 0, 0)
	if t4.Weekday() == 2 { pass = pass + 1 }
	if t4.WeekdayName() == "Tuesday" { pass = pass + 1 }

	// Pre-epoch: 1969-12-31 was a Wednesday.
	var t5 time.Time = time.Date(1969, 12, 31, 0, 0, 0, 0)
	if t5.Weekday() == 3 { pass = pass + 1 }
	if t5.WeekdayName() == "Wednesday" { pass = pass + 1 }

	// Walk a week from Thursday epoch → expect all 7 days.
	var seenAll bool = true
	for i := 0; i < 7; i++ {
		var ti time.Time = time.Date(1970, 1, 1 + i, 0, 0, 0, 0)
		var w int = ti.Weekday()
		if w < 0 { seenAll = false }
		if w >= 7 { seenAll = false }
	}
	if seenAll { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
