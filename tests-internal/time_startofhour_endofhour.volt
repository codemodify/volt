package main
import "log"
import "time"

// Positive test: (t Time).StartOfHour + (t Time).EndOfHour.

fun main() int {
	var pass int = 0

	// Basic mid-hour.
	var t1 time.Time = time.Date(2024, 6, 15, 14, 35, 27, 123456789)
	var sh time.Time = t1.StartOfHour()
	if sh.Year() == 2024 { pass = pass + 1 }
	if sh.Month() == 6 { pass = pass + 1 }
	if sh.Day() == 15 { pass = pass + 1 }
	if sh.Hour() == 14 { pass = pass + 1 }
	if sh.Minute() == 0 { pass = pass + 1 }
	if sh.Second() == 0 { pass = pass + 1 }

	var eh time.Time = t1.EndOfHour()
	if eh.Year() == 2024 { pass = pass + 1 }
	if eh.Day() == 15 { pass = pass + 1 }
	if eh.Hour() == 14 { pass = pass + 1 }
	if eh.Minute() == 59 { pass = pass + 1 }
	if eh.Second() == 59 { pass = pass + 1 }

	// On the hour boundary — should pin to itself.
	var t2 time.Time = time.Date(2024, 6, 15, 10, 0, 0, 0)
	var sh2 time.Time = t2.StartOfHour()
	if sh2.Hour() == 10 { pass = pass + 1 }
	if sh2.Minute() == 0 { pass = pass + 1 }
	if sh2.Second() == 0 { pass = pass + 1 }

	// EndOfHour preserves the hour even at minute=0.
	var eh2 time.Time = t2.EndOfHour()
	if eh2.Hour() == 10 { pass = pass + 1 }
	if eh2.Minute() == 59 { pass = pass + 1 }

	// Last hour of the day.
	var t3 time.Time = time.Date(2024, 6, 15, 23, 30, 0, 0)
	var sh3 time.Time = t3.StartOfHour()
	if sh3.Hour() == 23 { pass = pass + 1 }
	var eh3 time.Time = t3.EndOfHour()
	if eh3.Hour() == 23 { pass = pass + 1 }
	if eh3.Day() == 15 { pass = pass + 1 }   // still same day

	// First hour of the day.
	var t4 time.Time = time.Date(2024, 6, 15, 0, 45, 0, 0)
	var sh4 time.Time = t4.StartOfHour()
	if sh4.Hour() == 0 { pass = pass + 1 }
	if sh4.Day() == 15 { pass = pass + 1 }

	// IsBetween: t1 falls in [sh, eh].
	if t1.IsBetween(sh, eh) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
