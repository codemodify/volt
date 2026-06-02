package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// 2026-05-25 is a Monday → StartOfWeek == itself (at midnight).
	var mon time.Time = time.Date(2026, 5, 25, 14, 30, 0, 0)
	var sw1 time.Time = time.StartOfWeek(mon)
	if sw1.Year() == 2026 { pass = pass + 1 }
	if sw1.Month() == 5 { pass = pass + 1 }
	if sw1.Day() == 25 { pass = pass + 1 }
	if sw1.Hour() == 0 { pass = pass + 1 }
	if sw1.Minute() == 0 { pass = pass + 1 }

	// 2026-05-28 is a Thursday → StartOfWeek == 2026-05-25 Monday.
	var thu time.Time = time.Date(2026, 5, 28, 10, 0, 0, 0)
	var sw2 time.Time = time.StartOfWeek(thu)
	if sw2.Day() == 25 { pass = pass + 1 }
	if sw2.Month() == 5 { pass = pass + 1 }
	if sw2.Hour() == 0 { pass = pass + 1 }

	// 2026-05-31 is a Sunday → StartOfWeek == 2026-05-25 Monday.
	var sun time.Time = time.Date(2026, 5, 31, 23, 59, 0, 0)
	var sw3 time.Time = time.StartOfWeek(sun)
	if sw3.Day() == 25 { pass = pass + 1 }

	// 2026-05-30 Saturday → StartOfWeek == 2026-05-25 Monday.
	var sat time.Time = time.Date(2026, 5, 30, 10, 0, 0, 0)
	var sw4 time.Time = time.StartOfWeek(sat)
	if sw4.Day() == 25 { pass = pass + 1 }

	// EndOfWeek.
	// 2026-05-25 Monday → EndOfWeek == 2026-05-31 Sunday 23:59:59.
	var mon2 time.Time = time.Date(2026, 5, 25, 0, 0, 0, 0)
	var ew1 time.Time = time.EndOfWeek(mon2)
	if ew1.Day() == 31 { pass = pass + 1 }
	if ew1.Month() == 5 { pass = pass + 1 }
	if ew1.Hour() == 23 { pass = pass + 1 }
	if ew1.Minute() == 59 { pass = pass + 1 }

	// 2026-05-28 Thursday → EndOfWeek == 2026-05-31 Sunday.
	var thu2 time.Time = time.Date(2026, 5, 28, 10, 0, 0, 0)
	var ew2 time.Time = time.EndOfWeek(thu2)
	if ew2.Day() == 31 { pass = pass + 1 }

	// 2026-05-31 Sunday → EndOfWeek == itself (Sunday is already EOW).
	var sun2 time.Time = time.Date(2026, 5, 31, 10, 0, 0, 0)
	var ew3 time.Time = time.EndOfWeek(sun2)
	if ew3.Day() == 31 { pass = pass + 1 }
	if ew3.Hour() == 23 { pass = pass + 1 }

	// StartOfWeek then EndOfWeek span the same ISO week (Mon..Sun).
	var t1 time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	var sow time.Time = time.StartOfWeek(t1)
	var t1b time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	var eow time.Time = time.EndOfWeek(t1b)
	// Diff in days: Mon..Sun is 6 days + nanos (essentially 7 days - 1ns).
	var diffDays int = time.DiffDays(eow, sow)
	if diffDays == 6 { pass = pass + 1 }

	// Week crosses month boundary: 2026-04-30 Thursday → StartOfWeek 2026-04-27 Monday.
	var t2 time.Time = time.Date(2026, 4, 30, 10, 0, 0, 0)
	var sw5 time.Time = time.StartOfWeek(t2)
	if sw5.Day() == 27 { pass = pass + 1 }
	if sw5.Month() == 4 { pass = pass + 1 }

	// Week crosses year boundary: 2026-01-01 Thursday → StartOfWeek 2025-12-29 Monday.
	var t3 time.Time = time.Date(2026, 1, 1, 0, 0, 0, 0)
	var sw6 time.Time = time.StartOfWeek(t3)
	if sw6.Year() == 2025 { pass = pass + 1 }
	if sw6.Month() == 12 { pass = pass + 1 }
	if sw6.Day() == 29 { pass = pass + 1 }

	// Result is always a weekday (Monday).
	var t4 time.Time = time.Date(2026, 6, 15, 0, 0, 0, 0)
	var sow4 time.Time = time.StartOfWeek(t4)
	if sow4.Weekday() == 1 { pass = pass + 1 }   // Monday = 1

	// EndOfWeek result is always a Sunday.
	var t5 time.Time = time.Date(2026, 6, 15, 0, 0, 0, 0)
	var eow5 time.Time = time.EndOfWeek(t5)
	if eow5.Weekday() == 0 { pass = pass + 1 }   // Sunday = 0

	log.Println("pass=%d", pass)
	if pass == 25 { ret 42 }
	ret 0
}
