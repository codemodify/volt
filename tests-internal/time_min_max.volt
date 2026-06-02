package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	var earlier time.Time = time.Date(2024, 1, 1, 0, 0, 0, 0)
	var later time.Time = time.Date(2025, 1, 1, 0, 0, 0, 0)

	// MinTime — picks earlier.
	var m1 time.Time = time.MinTime(earlier, later)
	if m1.Year() == 2024 { pass = pass + 1 }

	// Order doesn't matter.
	var m2 time.Time = time.MinTime(later, earlier)
	if m2.Year() == 2024 { pass = pass + 1 }

	// MaxTime — picks later.
	var M1 time.Time = time.MaxTime(earlier, later)
	if M1.Year() == 2025 { pass = pass + 1 }

	var M2 time.Time = time.MaxTime(later, earlier)
	if M2.Year() == 2025 { pass = pass + 1 }

	// Equal times — left bias.
	var t1 time.Time = time.Date(2024, 6, 15, 12, 0, 0, 0)
	var t2 time.Time = time.Date(2024, 6, 15, 12, 0, 0, 0)
	var m3 time.Time = time.MinTime(t1, t2)
	if m3.Year() == 2024 { pass = pass + 1 }
	if m3.Month() == 6 { pass = pass + 1 }
	var M3 time.Time = time.MaxTime(t1, t2)
	if M3.Year() == 2024 { pass = pass + 1 }
	if M3.Day() == 15 { pass = pass + 1 }

	// Use case: bound a deadline.
	var userDeadline time.Time = time.Date(2026, 12, 31, 23, 59, 59, 0)
	var systemMax time.Time = time.Date(2026, 6, 30, 0, 0, 0, 0)
	var deadline time.Time = time.MinTime(userDeadline, systemMax)
	if deadline.Month() == 6 { pass = pass + 1 }
	if deadline.Year() == 2026 { pass = pass + 1 }

	// Use case: earliest-allowed start.
	var now time.Time = time.Date(2025, 5, 1, 10, 0, 0, 0)
	var scheduledStart time.Time = time.Date(2025, 5, 1, 9, 0, 0, 0)
	var start time.Time = time.MaxTime(now, scheduledStart)
	if start.Hour() == 10 { pass = pass + 1 }

	// MinTime ∘ MaxTime ordering with three values.
	var a time.Time = time.Date(2020, 1, 1, 0, 0, 0, 0)
	var b time.Time = time.Date(2022, 1, 1, 0, 0, 0, 0)
	var c time.Time = time.Date(2024, 1, 1, 0, 0, 0, 0)
	var ab time.Time = time.MaxTime(a, b)
	var abc time.Time = time.MaxTime(ab, c)
	if abc.Year() == 2024 { pass = pass + 1 }
	var aa time.Time = time.MinTime(a, b)
	var aac time.Time = time.MinTime(aa, c)
	if aac.Year() == 2020 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
