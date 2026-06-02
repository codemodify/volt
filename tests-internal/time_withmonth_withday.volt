package main
import "log"
import "time"

// Positive test: (t Time).WithMonth + WithDay.

fun main() int {
	var pass int = 0

	var t1 time.Time = time.Date(2024, 6, 15, 9, 30, 45, 0)

	// WithMonth — keeps year, day, time.
	var m1 time.Time = t1.WithMonth(1)
	if m1.Month() == 1 { pass = pass + 1 }
	if m1.Year() == 2024 { pass = pass + 1 }
	if m1.Day() == 15 { pass = pass + 1 }
	if m1.Hour() == 9 { pass = pass + 1 }
	if m1.Second() == 45 { pass = pass + 1 }

	// WithMonth — December.
	var dec time.Time = t1.WithMonth(12)
	if dec.Month() == 12 { pass = pass + 1 }
	if dec.Day() == 15 { pass = pass + 1 }

	// WithMonth — fixed-point (same month).
	var samem time.Time = t1.WithMonth(6)
	if samem.Sub(t1) == 0 { pass = pass + 1 }

	// WithDay — keeps year, month, time.
	var d1 time.Time = t1.WithDay(1)
	if d1.Day() == 1 { pass = pass + 1 }
	if d1.Year() == 2024 { pass = pass + 1 }
	if d1.Month() == 6 { pass = pass + 1 }
	if d1.Hour() == 9 { pass = pass + 1 }
	if d1.Minute() == 30 { pass = pass + 1 }
	if d1.Second() == 45 { pass = pass + 1 }

	// WithDay — day 30.
	var d30 time.Time = t1.WithDay(30)
	if d30.Day() == 30 { pass = pass + 1 }
	if d30.Month() == 6 { pass = pass + 1 }

	// WithDay — overflow spills (day=31 on a 30-day month → next month day 1).
	var overflow time.Time = t1.WithDay(31)
	if overflow.Month() == 7 { pass = pass + 1 }
	if overflow.Day() == 1 { pass = pass + 1 }

	// WithMonth — Feb on a 31st-day source overflows.
	// June 15 in Feb of same year = Feb 15. Not an overflow case.
	var feb time.Time = t1.WithMonth(2)
	if feb.Month() == 2 { pass = pass + 1 }
	if feb.Day() == 15 { pass = pass + 1 }

	// Method chaining.
	var chain time.Time = t1.WithMonth(1).WithDay(1)
	if chain.Year() == 2024 { pass = pass + 1 }
	if chain.Month() == 1 { pass = pass + 1 }
	if chain.Day() == 1 { pass = pass + 1 }
	if chain.Hour() == 9 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
