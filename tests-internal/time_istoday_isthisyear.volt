package main
import "log"
import "time"

// Positive test: (t Time).IsToday + (t Time).IsThisYear.

fun main() int {
	var pass int = 0

	// Build "now" via the Now() ns; should be today and this year.
	var now time.Time = new time.Time { ns: time.Now() }
	if now.IsToday() { pass = pass + 1 }
	if now.IsThisYear() { pass = pass + 1 }

	// One day in the past — not today.
	var y time.Time = now.Yesterday()
	if !y.IsToday() { pass = pass + 1 }

	// One day in the future — not today.
	var tm time.Time = now.Tomorrow()
	if !tm.IsToday() { pass = pass + 1 }

	// Five years ago — not this year.
	var fiveBack time.Time = now.AddDate(-5, 0, 0)
	if !fiveBack.IsThisYear() { pass = pass + 1 }

	// Five years forward — not this year.
	var fiveAhead time.Time = now.AddDate(5, 0, 0)
	if !fiveAhead.IsThisYear() { pass = pass + 1 }

	// A different known historical date — not today (almost certainly not).
	var historic time.Time = time.Date(1970, 1, 1, 0, 0, 0, 0)
	if !historic.IsToday() { pass = pass + 1 }
	if !historic.IsThisYear() { pass = pass + 1 }

	// Two seconds from now should still be today (unless we cross midnight — very rare).
	var soon time.Time = now.AddSeconds(2)
	if soon.IsToday() { pass = pass + 1 }

	// One hour ago is still today (unless we just crossed midnight — also rare).
	var earlier time.Time = now.AddHours(-1)
	if earlier.IsToday() { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 10 { ret 42 }
	ret 0
}
