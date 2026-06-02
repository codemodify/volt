package main
import "log"
import "time"

// Positive test: (t Time).TimeString + TimeStringShort.

fun main() int {
	var pass int = 0

	// Midnight.
	var midnight time.Time = time.Date(2024, 6, 15, 0, 0, 0, 0)
	if midnight.TimeString() == "00:00:00" { pass = pass + 1 }
	if midnight.TimeStringShort() == "00:00" { pass = pass + 1 }

	// Noon.
	var noon time.Time = time.Date(2024, 6, 15, 12, 0, 0, 0)
	if noon.TimeString() == "12:00:00" { pass = pass + 1 }
	if noon.TimeStringShort() == "12:00" { pass = pass + 1 }

	// 3:05:42 PM (15:05:42).
	var t1 time.Time = time.Date(2024, 6, 15, 15, 5, 42, 0)
	if t1.TimeString() == "15:05:42" { pass = pass + 1 }
	if t1.TimeStringShort() == "15:05" { pass = pass + 1 }

	// 9:30 AM.
	var t2 time.Time = time.Date(2024, 6, 15, 9, 30, 0, 0)
	if t2.TimeString() == "09:30:00" { pass = pass + 1 }
	if t2.TimeStringShort() == "09:30" { pass = pass + 1 }

	// 23:59:59.
	var lastSec time.Time = time.Date(2024, 6, 15, 23, 59, 59, 0)
	if lastSec.TimeString() == "23:59:59" { pass = pass + 1 }
	if lastSec.TimeStringShort() == "23:59" { pass = pass + 1 }

	// Single-digit fields pad correctly.
	var single time.Time = time.Date(2024, 6, 15, 4, 7, 9, 0)
	if single.TimeString() == "04:07:09" { pass = pass + 1 }
	if single.TimeStringShort() == "04:07" { pass = pass + 1 }

	// Nanoseconds don't affect output.
	var withNanos time.Time = time.Date(2024, 6, 15, 10, 20, 30, 999999999)
	if withNanos.TimeString() == "10:20:30" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
