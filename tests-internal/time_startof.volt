package main
import "log"
import "time"

// Positive test: (t Time).StartOfDay + EndOfDay + StartOfMonth + StartOfYear.

fun main() int {
	var pass int = 0

	var t time.Time = time.Date(2024, 3, 15, 14, 30, 45, 123456789)

	// StartOfDay — same date, midnight.
	var sd time.Time = t.StartOfDay()
	if sd.Year() == 2024 { pass = pass + 1 }
	if sd.Month() == 3 { pass = pass + 1 }
	if sd.Day() == 15 { pass = pass + 1 }
	if sd.Hour() == 0 { pass = pass + 1 }
	if sd.Minute() == 0 { pass = pass + 1 }
	if sd.Second() == 0 { pass = pass + 1 }

	// EndOfDay — same date, last nanosecond.
	var ed time.Time = t.EndOfDay()
	if ed.Year() == 2024 { pass = pass + 1 }
	if ed.Month() == 3 { pass = pass + 1 }
	if ed.Day() == 15 { pass = pass + 1 }
	if ed.Hour() == 23 { pass = pass + 1 }
	if ed.Minute() == 59 { pass = pass + 1 }
	if ed.Second() == 59 { pass = pass + 1 }

	// StartOfMonth — first day of month, midnight.
	var sm time.Time = t.StartOfMonth()
	if sm.Year() == 2024 { pass = pass + 1 }
	if sm.Month() == 3 { pass = pass + 1 }
	if sm.Day() == 1 { pass = pass + 1 }
	if sm.Hour() == 0 { pass = pass + 1 }

	// StartOfYear — Jan 1, midnight.
	var sy time.Time = t.StartOfYear()
	if sy.Year() == 2024 { pass = pass + 1 }
	if sy.Month() == 1 { pass = pass + 1 }
	if sy.Day() == 1 { pass = pass + 1 }
	if sy.Hour() == 0 { pass = pass + 1 }

	// Verify the original is on the same day as its StartOfDay.
	if t.IsSameDay(sd) { pass = pass + 1 }
	if t.IsSameDay(ed) { pass = pass + 1 }

	// StartOfDay then EndOfDay are < 1 day apart.
	if ed.SecondsBetween(sd) == 86399 { pass = pass + 1 }   // 23h59m59s

	// StartOfMonth on the 1st returns itself (modulo time-of-day).
	var firstDay time.Time = time.Date(2024, 4, 1, 12, 0, 0, 0)
	var smFirst time.Time = firstDay.StartOfMonth()
	if smFirst.Day() == 1 { pass = pass + 1 }
	if smFirst.IsSameDay(firstDay) { pass = pass + 1 }

	// StartOfYear from December — wraps back to Jan 1 of same year.
	var dec time.Time = time.Date(2024, 12, 31, 23, 59, 59, 0)
	var syDec time.Time = dec.StartOfYear()
	if syDec.Month() == 1 { pass = pass + 1 }
	if syDec.Day() == 1 { pass = pass + 1 }
	if syDec.Year() == 2024 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 28 { ret 42 }
	ret 0
}
