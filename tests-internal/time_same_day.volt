package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// Same day, different times.
	var a1 time.Time = time.Date(2026, 5, 28, 9, 0, 0, 0)
	var b1 time.Time = time.Date(2026, 5, 28, 17, 30, 45, 0)
	if time.IsSameDay(a1, b1) { pass = pass + 1 }

	// Same day, exact same instant.
	var a2 time.Time = time.Date(2026, 5, 28, 12, 0, 0, 0)
	var b2 time.Time = time.Date(2026, 5, 28, 12, 0, 0, 0)
	if time.IsSameDay(a2, b2) { pass = pass + 1 }

	// Adjacent days.
	var a3 time.Time = time.Date(2026, 5, 28, 23, 59, 59, 0)
	var b3 time.Time = time.Date(2026, 5, 29, 0, 0, 1, 0)
	if !time.IsSameDay(a3, b3) { pass = pass + 1 }

	// Same day-of-month, different month.
	var a4 time.Time = time.Date(2026, 5, 15, 12, 0, 0, 0)
	var b4 time.Time = time.Date(2026, 6, 15, 12, 0, 0, 0)
	if !time.IsSameDay(a4, b4) { pass = pass + 1 }

	// Same day-of-month + month, different year.
	var a5 time.Time = time.Date(2025, 5, 15, 12, 0, 0, 0)
	var b5 time.Time = time.Date(2026, 5, 15, 12, 0, 0, 0)
	if !time.IsSameDay(a5, b5) { pass = pass + 1 }

	// Symmetric.
	var a6 time.Time = time.Date(2026, 1, 1, 0, 0, 0, 0)
	var b6 time.Time = time.Date(2026, 1, 1, 23, 59, 59, 0)
	if time.IsSameDay(a6, b6) { pass = pass + 1 }
	var a6b time.Time = time.Date(2026, 1, 1, 0, 0, 0, 0)
	var b6b time.Time = time.Date(2026, 1, 1, 23, 59, 59, 0)
	if time.IsSameDay(b6b, a6b) { pass = pass + 1 }

	// Today / yesterday / tomorrow against current time.
	// Now() should produce a Time that satisfies IsToday.
	var nowT time.Time = time.FromNano(time.Now())
	if time.IsToday(nowT) { pass = pass + 1 }
	var nowT2 time.Time = time.FromNano(time.Now())
	if !time.IsYesterday(nowT2) { pass = pass + 1 }
	var nowT3 time.Time = time.FromNano(time.Now())
	if !time.IsTomorrow(nowT3) { pass = pass + 1 }

	// Yesterday and tomorrow.
	var nowT4 time.Time = time.FromNano(time.Now())
	var yest time.Time = time.AddDays(nowT4, -1)
	if time.IsYesterday(yest) { pass = pass + 1 }
	var nowT5 time.Time = time.FromNano(time.Now())
	var tom time.Time = time.AddDays(nowT5, 1)
	if time.IsTomorrow(tom) { pass = pass + 1 }

	// Two-days-ago is not yesterday.
	var nowT6 time.Time = time.FromNano(time.Now())
	var twoAgo time.Time = time.AddDays(nowT6, -2)
	if !time.IsYesterday(twoAgo) { pass = pass + 1 }

	// Cross-property: IsSameDay(t, t) is always true.
	var t1 time.Time = time.Date(2024, 2, 29, 0, 0, 0, 0)   // leap day
	var t1b time.Time = time.Date(2024, 2, 29, 0, 0, 0, 0)
	if time.IsSameDay(t1, t1b) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
