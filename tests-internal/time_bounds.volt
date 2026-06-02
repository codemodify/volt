package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// StartOfDay.
	var t1 time.Time = time.Date(2026, 5, 28, 14, 30, 45, 500000000)
	var s1 time.Time = time.StartOfDay(t1)
	if s1.Year() == 2026 { pass = pass + 1 }
	if s1.Month() == 5 { pass = pass + 1 }
	if s1.Day() == 28 { pass = pass + 1 }
	if s1.Hour() == 0 { pass = pass + 1 }
	if s1.Minute() == 0 { pass = pass + 1 }
	if s1.Second() == 0 { pass = pass + 1 }

	// EndOfDay.
	var t2 time.Time = time.Date(2026, 5, 28, 14, 30, 45, 0)
	var s2 time.Time = time.EndOfDay(t2)
	if s2.Day() == 28 { pass = pass + 1 }
	if s2.Hour() == 23 { pass = pass + 1 }
	if s2.Minute() == 59 { pass = pass + 1 }
	if s2.Second() == 59 { pass = pass + 1 }

	// StartOfDay is idempotent.
	var t3 time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	var s3 time.Time = time.StartOfDay(t3)
	if s3.Day() == 28 { pass = pass + 1 }
	if s3.Hour() == 0 { pass = pass + 1 }

	// StartOfDay then EndOfDay are on same calendar day.
	var t4 time.Time = time.Date(2026, 5, 28, 14, 0, 0, 0)
	var sod time.Time = time.StartOfDay(t4)
	var t4b time.Time = time.Date(2026, 5, 28, 14, 0, 0, 0)
	var eod time.Time = time.EndOfDay(t4b)
	if time.IsSameDay(sod, eod) { pass = pass + 1 }

	// EndOfDay > StartOfDay (after returns true).
	var t5 time.Time = time.Date(2026, 5, 28, 12, 0, 0, 0)
	var sod2 time.Time = time.StartOfDay(t5)
	var t5b time.Time = time.Date(2026, 5, 28, 12, 0, 0, 0)
	var eod2 time.Time = time.EndOfDay(t5b)
	if eod2.After(sod2) { pass = pass + 1 }

	// StartOfMonth.
	var t6 time.Time = time.Date(2026, 5, 15, 14, 30, 0, 0)
	var sm time.Time = time.StartOfMonth(t6)
	if sm.Year() == 2026 { pass = pass + 1 }
	if sm.Month() == 5 { pass = pass + 1 }
	if sm.Day() == 1 { pass = pass + 1 }
	if sm.Hour() == 0 { pass = pass + 1 }

	// EndOfMonth for 31-day month.
	var t7 time.Time = time.Date(2026, 5, 15, 0, 0, 0, 0)
	var em7 time.Time = time.EndOfMonth(t7)
	if em7.Day() == 31 { pass = pass + 1 }
	if em7.Month() == 5 { pass = pass + 1 }
	if em7.Hour() == 23 { pass = pass + 1 }

	// EndOfMonth for 30-day month (April).
	var t8 time.Time = time.Date(2026, 4, 15, 0, 0, 0, 0)
	var em8 time.Time = time.EndOfMonth(t8)
	if em8.Day() == 30 { pass = pass + 1 }
	if em8.Month() == 4 { pass = pass + 1 }

	// EndOfMonth for February (non-leap).
	var t9 time.Time = time.Date(2026, 2, 15, 0, 0, 0, 0)
	var em9 time.Time = time.EndOfMonth(t9)
	if em9.Day() == 28 { pass = pass + 1 }

	// EndOfMonth for February (leap).
	var t10 time.Time = time.Date(2024, 2, 15, 0, 0, 0, 0)
	var em10 time.Time = time.EndOfMonth(t10)
	if em10.Day() == 29 { pass = pass + 1 }

	// StartOfMonth idempotent.
	var t11 time.Time = time.Date(2026, 5, 1, 0, 0, 0, 0)
	var sm11 time.Time = time.StartOfMonth(t11)
	if sm11.Day() == 1 { pass = pass + 1 }

	// Use case: range query "events between start and end of day".
	var event time.Time = time.Date(2026, 5, 28, 10, 0, 0, 0)
	var lo time.Time = time.StartOfDay(event)
	var event2 time.Time = time.Date(2026, 5, 28, 10, 0, 0, 0)
	var hi time.Time = time.EndOfDay(event2)
	var ev3 time.Time = time.Date(2026, 5, 28, 10, 0, 0, 0)
	if time.TimeIsBetween(ev3, lo, hi) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
