package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// StartOfYear.
	var t1 time.Time = time.Date(2026, 5, 28, 14, 30, 45, 0)
	var sy time.Time = time.StartOfYear(t1)
	if sy.Year() == 2026 { pass = pass + 1 }
	if sy.Month() == 1 { pass = pass + 1 }
	if sy.Day() == 1 { pass = pass + 1 }
	if sy.Hour() == 0 { pass = pass + 1 }
	if sy.Minute() == 0 { pass = pass + 1 }

	// EndOfYear.
	var t2 time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	var ey time.Time = time.EndOfYear(t2)
	if ey.Year() == 2026 { pass = pass + 1 }
	if ey.Month() == 12 { pass = pass + 1 }
	if ey.Day() == 31 { pass = pass + 1 }
	if ey.Hour() == 23 { pass = pass + 1 }
	if ey.Minute() == 59 { pass = pass + 1 }
	if ey.Second() == 59 { pass = pass + 1 }

	// StartOfYear is idempotent.
	var t3 time.Time = time.Date(2026, 1, 1, 0, 0, 0, 0)
	var sy3 time.Time = time.StartOfYear(t3)
	if sy3.Year() == 2026 { pass = pass + 1 }
	if sy3.Day() == 1 { pass = pass + 1 }

	// StartOfHour.
	var t4 time.Time = time.Date(2026, 5, 28, 14, 30, 45, 0)
	var sh time.Time = time.StartOfHour(t4)
	if sh.Year() == 2026 { pass = pass + 1 }
	if sh.Month() == 5 { pass = pass + 1 }
	if sh.Day() == 28 { pass = pass + 1 }
	if sh.Hour() == 14 { pass = pass + 1 }
	if sh.Minute() == 0 { pass = pass + 1 }
	if sh.Second() == 0 { pass = pass + 1 }

	// EndOfHour.
	var t5 time.Time = time.Date(2026, 5, 28, 14, 30, 45, 0)
	var eh time.Time = time.EndOfHour(t5)
	if eh.Hour() == 14 { pass = pass + 1 }
	if eh.Minute() == 59 { pass = pass + 1 }
	if eh.Second() == 59 { pass = pass + 1 }

	// StartOfHour idempotent.
	var t6 time.Time = time.Date(2026, 5, 28, 14, 0, 0, 0)
	var sh6 time.Time = time.StartOfHour(t6)
	if sh6.Hour() == 14 { pass = pass + 1 }
	if sh6.Minute() == 0 { pass = pass + 1 }

	// StartOfHour at hour 0.
	var t7 time.Time = time.Date(2026, 5, 28, 0, 30, 0, 0)
	var sh7 time.Time = time.StartOfHour(t7)
	if sh7.Hour() == 0 { pass = pass + 1 }

	// EndOfHour at hour 23.
	var t8 time.Time = time.Date(2026, 5, 28, 23, 30, 0, 0)
	var eh8 time.Time = time.EndOfHour(t8)
	if eh8.Hour() == 23 { pass = pass + 1 }
	if eh8.Day() == 28 { pass = pass + 1 }

	// Year-bound range query use case.
	var event time.Time = time.Date(2026, 7, 15, 12, 0, 0, 0)
	var lo time.Time = time.StartOfYear(event)
	var event2 time.Time = time.Date(2026, 7, 15, 12, 0, 0, 0)
	var hi time.Time = time.EndOfYear(event2)
	var ev3 time.Time = time.Date(2026, 7, 15, 12, 0, 0, 0)
	if time.TimeIsBetween(ev3, lo, hi) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 28 { ret 42 }
	ret 0
}
