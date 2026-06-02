package main
import "log"
import "time"

// Positive test: (t Time).IsThisMonth + (t Time).IsThisWeek.

fun main() int {
	var pass int = 0

	var now time.Time = new time.Time { ns: time.Now() }

	// now is in this month + this week.
	if now.IsThisMonth() { pass = pass + 1 }
	if now.IsThisWeek() { pass = pass + 1 }

	// 2 seconds from now still in this month + this week (unless on the boundary — rare).
	var soon time.Time = now.AddSeconds(2)
	if soon.IsThisMonth() { pass = pass + 1 }
	if soon.IsThisWeek() { pass = pass + 1 }

	// Roughly 3 months ago — definitely not this month (and unlikely this week).
	var threeBack time.Time = now.AddDate(0, -3, 0)
	if !threeBack.IsThisMonth() { pass = pass + 1 }
	if !threeBack.IsThisWeek() { pass = pass + 1 }

	// Roughly 3 months ahead — not this month.
	var threeAhead time.Time = now.AddDate(0, 3, 0)
	if !threeAhead.IsThisMonth() { pass = pass + 1 }
	if !threeAhead.IsThisWeek() { pass = pass + 1 }

	// 30 days back — not this week.
	var monthBack time.Time = now.AddDate(0, 0, -30)
	if !monthBack.IsThisWeek() { pass = pass + 1 }

	// 30 days forward — not this week.
	var monthAhead time.Time = now.AddDate(0, 0, 30)
	if !monthAhead.IsThisWeek() { pass = pass + 1 }

	// Historic date — not this month, not this week.
	var historic time.Time = time.Date(2000, 1, 1, 0, 0, 0, 0)
	if !historic.IsThisMonth() { pass = pass + 1 }
	if !historic.IsThisWeek() { pass = pass + 1 }

	// Far future — not this month, not this week.
	var farFuture time.Time = time.Date(2099, 12, 31, 0, 0, 0, 0)
	if !farFuture.IsThisMonth() { pass = pass + 1 }
	if !farFuture.IsThisWeek() { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
