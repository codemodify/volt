package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	var t1 time.Time = time.Date(2026, 5, 28, 12, 0, 0, 0)

	// AddDays(t, 1) → next day.
	var t2 time.Time = time.AddDays(t1, 1)
	if t2.Year() == 2026 { pass = pass + 1 }
	if t2.Month() == 5 { pass = pass + 1 }
	if t2.Day() == 29 { pass = pass + 1 }
	if t2.Hour() == 12 { pass = pass + 1 }

	// AddDays(t, 0) → same time.
	var t3 time.Time = time.AddDays(t1, 0)
	if t3.Day() == 28 { pass = pass + 1 }

	// AddDays(t, -1) → previous day.
	var t4 time.Time = time.AddDays(t1, -1)
	if t4.Day() == 27 { pass = pass + 1 }
	if t4.Month() == 5 { pass = pass + 1 }

	// AddDays across month boundary.
	var t5 time.Time = time.Date(2026, 1, 31, 0, 0, 0, 0)
	var t6 time.Time = time.AddDays(t5, 1)
	if t6.Month() == 2 { pass = pass + 1 }
	if t6.Day() == 1 { pass = pass + 1 }

	// AddDays across year boundary.
	var t7 time.Time = time.Date(2026, 12, 31, 23, 0, 0, 0)
	var t8 time.Time = time.AddDays(t7, 1)
	if t8.Year() == 2027 { pass = pass + 1 }
	if t8.Month() == 1 { pass = pass + 1 }
	if t8.Day() == 1 { pass = pass + 1 }
	if t8.Hour() == 23 { pass = pass + 1 }

	// AddHours(t, 1) → next hour.
	var t9 time.Time = time.AddHours(t1, 1)
	if t9.Hour() == 13 { pass = pass + 1 }
	if t9.Day() == 28 { pass = pass + 1 }

	// AddHours rollover.
	var t10 time.Time = time.AddHours(t1, 13)
	if t10.Day() == 29 { pass = pass + 1 }
	if t10.Hour() == 1 { pass = pass + 1 }

	// AddHours negative.
	var t11 time.Time = time.AddHours(t1, -1)
	if t11.Hour() == 11 { pass = pass + 1 }

	// DiffDays — sign-preserving, truncate-toward-zero.
	var a1 time.Time = time.Date(2026, 5, 1, 0, 0, 0, 0)
	var b1 time.Time = time.Date(2026, 5, 10, 0, 0, 0, 0)
	if time.DiffDays(b1, a1) == 9 { pass = pass + 1 }
	var a1b time.Time = time.Date(2026, 5, 1, 0, 0, 0, 0)
	var b1b time.Time = time.Date(2026, 5, 10, 0, 0, 0, 0)
	if time.DiffDays(a1b, b1b) == -9 { pass = pass + 1 }

	// DiffDays truncates: 36 hours → 1 day.
	var a2 time.Time = time.Date(2026, 5, 1, 0, 0, 0, 0)
	var b2 time.Time = time.Date(2026, 5, 2, 12, 0, 0, 0)
	if time.DiffDays(b2, a2) == 1 { pass = pass + 1 }

	// Same instant → 0 days.
	var a3 time.Time = time.Date(2026, 5, 1, 0, 0, 0, 0)
	var b3 time.Time = time.Date(2026, 5, 1, 0, 0, 0, 0)
	if time.DiffDays(b3, a3) == 0 { pass = pass + 1 }

	// DiffHours.
	var a4 time.Time = time.Date(2026, 5, 1, 0, 0, 0, 0)
	var b4 time.Time = time.Date(2026, 5, 1, 5, 0, 0, 0)
	if time.DiffHours(b4, a4) == 5 { pass = pass + 1 }
	var a4b time.Time = time.Date(2026, 5, 1, 0, 0, 0, 0)
	var b4b time.Time = time.Date(2026, 5, 1, 5, 30, 0, 0)
	// Truncate toward zero: 5.5 → 5.
	if time.DiffHours(b4b, a4b) == 5 { pass = pass + 1 }
	var a4c time.Time = time.Date(2026, 5, 1, 5, 0, 0, 0)
	var b4c time.Time = time.Date(2026, 5, 1, 0, 0, 0, 0)
	if time.DiffHours(b4c, a4c) == -5 { pass = pass + 1 }

	// Round-trip: AddDays(t, n) then DiffDays back == n.
	var aRT time.Time = time.Date(2026, 5, 1, 12, 0, 0, 0)
	var aRT2 time.Time = time.AddDays(aRT, 7)
	var aRT3 time.Time = time.Date(2026, 5, 1, 12, 0, 0, 0)
	if time.DiffDays(aRT2, aRT3) == 7 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
