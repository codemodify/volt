package main
import "log"
import "time"

// Positive test: (t Time).TruncateToMinute + TruncateToHour.

fun main() int {
	var pass int = 0

	// TruncateToMinute — clamp seconds and ns.
	var t1 time.Time = time.Date(2024, 6, 15, 12, 30, 45, 123456789)
	var m1 time.Time = t1.TruncateToMinute()
	if m1.Hour() == 12 { pass = pass + 1 }
	if m1.Minute() == 30 { pass = pass + 1 }
	if m1.Second() == 0 { pass = pass + 1 }

	// TruncateToMinute — never rounds up (unlike Round).
	var t59 time.Time = time.Date(2024, 6, 15, 12, 30, 59, 999999999)
	var m59 time.Time = t59.TruncateToMinute()
	if m59.Minute() == 30 { pass = pass + 1 }
	if m59.Second() == 0 { pass = pass + 1 }

	// TruncateToMinute — already on boundary stays.
	var exact time.Time = time.Date(2024, 6, 15, 12, 30, 0, 0)
	var mExact time.Time = exact.TruncateToMinute()
	if mExact.Minute() == 30 { pass = pass + 1 }

	// TruncateToHour — clamp minute, second, ns.
	var t2 time.Time = time.Date(2024, 6, 15, 14, 45, 30, 0)
	var h1 time.Time = t2.TruncateToHour()
	if h1.Hour() == 14 { pass = pass + 1 }
	if h1.Minute() == 0 { pass = pass + 1 }
	if h1.Second() == 0 { pass = pass + 1 }

	// TruncateToHour — never rounds up.
	var t59min time.Time = time.Date(2024, 6, 15, 14, 59, 59, 0)
	var h59 time.Time = t59min.TruncateToHour()
	if h59.Hour() == 14 { pass = pass + 1 }
	if h59.Minute() == 0 { pass = pass + 1 }

	// TruncateToHour — already on boundary stays.
	var hExact time.Time = time.Date(2024, 6, 15, 16, 0, 0, 0)
	var th time.Time = hExact.TruncateToHour()
	if th.Hour() == 16 { pass = pass + 1 }
	if th.Minute() == 0 { pass = pass + 1 }

	// TruncateToHour does NOT cross day boundary (unlike Round at 23:59 → next day).
	var late time.Time = time.Date(2024, 6, 15, 23, 59, 59, 999999999)
	var truncLate time.Time = late.TruncateToHour()
	if truncLate.Day() == 15 { pass = pass + 1 }
	if truncLate.Hour() == 23 { pass = pass + 1 }

	// Identity: Truncate <= Round for positive seconds.
	if t1.TruncateToMinute().Sub(t1.RoundToMinute()) <= 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
