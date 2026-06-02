package main
import "log"
import "time"

// Positive test: (t Time).HoursBetween + MinutesBetween.

fun main() int {
	var pass int = 0

	// 0 hours / 0 minutes — same instant.
	var t1 time.Time = time.Date(2024, 3, 15, 12, 0, 0, 0)
	var t2 time.Time = time.Date(2024, 3, 15, 12, 0, 0, 0)
	if t1.HoursBetween(t2) == 0 { pass = pass + 1 }
	if t1.MinutesBetween(t2) == 0 { pass = pass + 1 }

	// 1 hour later.
	var t3 time.Time = time.Date(2024, 3, 15, 13, 0, 0, 0)
	if t3.HoursBetween(t1) == 1 { pass = pass + 1 }
	if t3.MinutesBetween(t1) == 60 { pass = pass + 1 }

	// 1 hour earlier → -1.
	var t4 time.Time = time.Date(2024, 3, 15, 11, 0, 0, 0)
	if t4.HoursBetween(t1) == -1 { pass = pass + 1 }
	if t4.MinutesBetween(t1) == -60 { pass = pass + 1 }

	// Partial hour — 30 minutes after t1.
	var t5 time.Time = time.Date(2024, 3, 15, 12, 30, 0, 0)
	if t5.HoursBetween(t1) == 0 { pass = pass + 1 }    // floor-div: 30 min → 0 hours
	if t5.MinutesBetween(t1) == 30 { pass = pass + 1 }

	// 90 minutes.
	var t6 time.Time = time.Date(2024, 3, 15, 13, 30, 0, 0)
	if t6.HoursBetween(t1) == 1 { pass = pass + 1 }     // floor 90 min → 1 hour
	if t6.MinutesBetween(t1) == 90 { pass = pass + 1 }

	// 23 hours.
	var t7 time.Time = time.Date(2024, 3, 16, 11, 0, 0, 0)
	if t7.HoursBetween(t1) == 23 { pass = pass + 1 }
	if t7.MinutesBetween(t1) == 1380 { pass = pass + 1 }   // 23 * 60

	// 24 hours = 1 day.
	var t8 time.Time = time.Date(2024, 3, 16, 12, 0, 0, 0)
	if t8.HoursBetween(t1) == 24 { pass = pass + 1 }
	if t8.MinutesBetween(t1) == 1440 { pass = pass + 1 }

	// One full year (non-leap day count).
	var y1 time.Time = time.Date(2024, 3, 15, 0, 0, 0, 0)
	var y2 time.Time = time.Date(2025, 3, 15, 0, 0, 0, 0)
	if y2.HoursBetween(y1) == 8760 { pass = pass + 1 }   // 365 * 24

	// Negative direction.
	if t1.HoursBetween(t8) == -24 { pass = pass + 1 }
	if t1.MinutesBetween(t8) == -1440 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
