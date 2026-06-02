package main
import "log"
import "time"

// Positive test: (t Time).IsWeekend + IsWeekday.

fun main() int {
	var pass int = 0

	// 2024-03-16 was a Saturday → weekend.
	var t1 time.Time = time.Date(2024, 3, 16, 12, 0, 0, 0)
	if t1.IsWeekend() { pass = pass + 1 }
	if !t1.IsWeekday() { pass = pass + 1 }

	// 2024-03-17 was a Sunday → weekend.
	var t2 time.Time = time.Date(2024, 3, 17, 12, 0, 0, 0)
	if t2.IsWeekend() { pass = pass + 1 }
	if !t2.IsWeekday() { pass = pass + 1 }

	// 2024-03-15 was a Friday → weekday.
	var t3 time.Time = time.Date(2024, 3, 15, 12, 0, 0, 0)
	if !t3.IsWeekend() { pass = pass + 1 }
	if t3.IsWeekday() { pass = pass + 1 }

	// 2024-03-18 was a Monday → weekday.
	var t4 time.Time = time.Date(2024, 3, 18, 12, 0, 0, 0)
	if !t4.IsWeekend() { pass = pass + 1 }
	if t4.IsWeekday() { pass = pass + 1 }

	// Epoch 1970-01-01 was a Thursday → weekday.
	var t5 time.Time = time.FromNano(0)
	if !t5.IsWeekend() { pass = pass + 1 }
	if t5.IsWeekday() { pass = pass + 1 }

	// 1969-12-28 was a Sunday → weekend (pre-epoch).
	var t6 time.Time = time.Date(1969, 12, 28, 12, 0, 0, 0)
	if t6.IsWeekend() { pass = pass + 1 }
	if !t6.IsWeekday() { pass = pass + 1 }

	// Walk a week starting 2024-05-26 (Sunday): expect Sun,Mon..Fri,Sat
	// pattern → 2 weekends, 5 weekdays in those 7 days.
	var weekendCount int = 0
	var weekdayCount int = 0
	for i := 0; i < 7; i++ {
		var t time.Time = time.Date(2024, 5, 26 + i, 0, 0, 0, 0)
		if t.IsWeekend() { weekendCount = weekendCount + 1 }
		if t.IsWeekday() { weekdayCount = weekdayCount + 1 }
	}
	if weekendCount == 2 { pass = pass + 1 }
	if weekdayCount == 5 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
