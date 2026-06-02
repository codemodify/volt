package main
import "log"
import "time"

// Positive test: (t Time).RoundToMinute + RoundToHour.

fun main() int {
	var pass int = 0

	// RoundToMinute — already on a minute boundary stays.
	var exact time.Time = time.Date(2024, 6, 15, 12, 30, 0, 0)
	var r1 time.Time = exact.RoundToMinute()
	if r1.Hour() == 12 { pass = pass + 1 }
	if r1.Minute() == 30 { pass = pass + 1 }
	if r1.Second() == 0 { pass = pass + 1 }

	// RoundToMinute — < 30s rounds down.
	var t29 time.Time = time.Date(2024, 6, 15, 12, 30, 29, 0)
	var r2 time.Time = t29.RoundToMinute()
	if r2.Minute() == 30 { pass = pass + 1 }
	if r2.Second() == 0 { pass = pass + 1 }

	// RoundToMinute — > 30s rounds up.
	var t31 time.Time = time.Date(2024, 6, 15, 12, 30, 31, 0)
	var r3 time.Time = t31.RoundToMinute()
	if r3.Minute() == 31 { pass = pass + 1 }
	if r3.Second() == 0 { pass = pass + 1 }

	// RoundToMinute — exactly 30s rounds up (away from zero on the half).
	var t30 time.Time = time.Date(2024, 6, 15, 12, 30, 30, 0)
	var r4 time.Time = t30.RoundToMinute()
	if r4.Minute() == 31 { pass = pass + 1 }

	// RoundToHour — already on hour boundary stays.
	var exactH time.Time = time.Date(2024, 6, 15, 14, 0, 0, 0)
	var rh1 time.Time = exactH.RoundToHour()
	if rh1.Hour() == 14 { pass = pass + 1 }
	if rh1.Minute() == 0 { pass = pass + 1 }

	// RoundToHour — < 30min rounds down.
	var t29min time.Time = time.Date(2024, 6, 15, 14, 29, 0, 0)
	var rh2 time.Time = t29min.RoundToHour()
	if rh2.Hour() == 14 { pass = pass + 1 }
	if rh2.Minute() == 0 { pass = pass + 1 }

	// RoundToHour — > 30min rounds up.
	var t31min time.Time = time.Date(2024, 6, 15, 14, 31, 0, 0)
	var rh3 time.Time = t31min.RoundToHour()
	if rh3.Hour() == 15 { pass = pass + 1 }

	// RoundToHour — exactly 30min rounds up.
	var t30min time.Time = time.Date(2024, 6, 15, 14, 30, 0, 0)
	var rh4 time.Time = t30min.RoundToHour()
	if rh4.Hour() == 15 { pass = pass + 1 }

	// RoundToHour — hour boundary day-spillover (23:45 → 24:00 → next-day 00:00).
	var late time.Time = time.Date(2024, 6, 15, 23, 45, 0, 0)
	var rhLate time.Time = late.RoundToHour()
	if rhLate.Day() == 16 { pass = pass + 1 }
	if rhLate.Hour() == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
