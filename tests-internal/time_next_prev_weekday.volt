package main
import "log"
import "time"

// Positive test: (t Time).NextWeekday + PrevWeekday.

fun main() int {
	var pass int = 0

	// Reference: 2024-05-26 is a Sunday (Weekday 0).
	var sun time.Time = time.Date(2024, 5, 26, 12, 0, 0, 0)

	// NextWeekday from Sunday → next Monday (May 27).
	var nm time.Time = sun.NextWeekday(1)
	if nm.Year() == 2024 { pass = pass + 1 }
	if nm.Month() == 5 { pass = pass + 1 }
	if nm.Day() == 27 { pass = pass + 1 }
	if nm.Weekday() == 1 { pass = pass + 1 }

	// NextWeekday from Sunday → next Sunday (advances 7 days).
	// May 26 + 7 = June 2 — verify both month rollover and weekday.
	var ns time.Time = sun.NextWeekday(0)
	if ns.Month() == 6 { pass = pass + 1 }
	if ns.Day() == 2 { pass = pass + 1 }
	if ns.DaysBetween(sun) == 7 { pass = pass + 1 }
	if ns.Weekday() == 0 { pass = pass + 1 }

	// NextWeekday from Sunday → next Saturday (6 days).
	var nsat time.Time = sun.NextWeekday(6)
	if nsat.DaysBetween(sun) == 6 { pass = pass + 1 }
	if nsat.Weekday() == 6 { pass = pass + 1 }

	// NextWeekday from Wednesday → next Sunday (4 days).
	var wed time.Time = time.Date(2024, 5, 29, 0, 0, 0, 0)
	var w_to_sun time.Time = wed.NextWeekday(0)
	if w_to_sun.DaysBetween(wed) == 4 { pass = pass + 1 }
	if w_to_sun.Weekday() == 0 { pass = pass + 1 }

	// PrevWeekday from Sunday → prev Saturday (1 day back).
	var psat time.Time = sun.PrevWeekday(6)
	if sun.DaysBetween(psat) == 1 { pass = pass + 1 }
	if psat.Weekday() == 6 { pass = pass + 1 }

	// PrevWeekday from Sunday → prev Sunday (7 days back).
	var psun time.Time = sun.PrevWeekday(0)
	if sun.DaysBetween(psun) == 7 { pass = pass + 1 }
	if psun.Weekday() == 0 { pass = pass + 1 }

	// PrevWeekday from Sunday → prev Monday (6 days back).
	var pmon time.Time = sun.PrevWeekday(1)
	if sun.DaysBetween(pmon) == 6 { pass = pass + 1 }
	if pmon.Weekday() == 1 { pass = pass + 1 }

	// Normalization — w=7 should be same as w=0.
	var n7 time.Time = sun.NextWeekday(7)
	var n0 time.Time = sun.NextWeekday(0)
	if n7.Equal(n0) { pass = pass + 1 }

	// w=-1 == w=6 (negative normalizes to positive).
	var nneg time.Time = sun.NextWeekday(-1)
	var n6 time.Time = sun.NextWeekday(6)
	if nneg.Equal(n6) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
