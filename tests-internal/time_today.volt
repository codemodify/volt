package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	var t time.Time = time.Today()

	// Today is at midnight (00:00:00).
	if t.Hour() == 0 { pass = pass + 1 }
	if t.Minute() == 0 { pass = pass + 1 }
	if t.Second() == 0 { pass = pass + 1 }

	// Year is reasonable for 2026+ test runs.
	if t.Year() >= 2026 { pass = pass + 1 }

	// Same day as a fresh FromNano(Now()).StartOfDay().
	var nowT time.Time = time.FromNano(time.Now())
	var startToday time.Time = nowT.StartOfDay()
	if t.Equal(startToday) { pass = pass + 1 }

	// Today is in the past (already happened).
	var t2 time.Time = time.Today()
	if t2.IsPast() { pass = pass + 1 }

	// DateString matches NowDate.
	var t3 time.Time = time.Today()
	if t3.DateString() == time.NowDate() { pass = pass + 1 }

	// Difference between Today's start and a later time is < 24h.
	var t4 time.Time = time.Today()
	var nowT2 time.Time = time.FromNano(time.Now())
	var diffNs int = nowT2.Sub(t4)
	if diffNs >= 0 { pass = pass + 1 }
	if diffNs < 86400 * 1000000000 { pass = pass + 1 }   // < 24h

	log.Println("pass=%d", pass)
	if pass == 9 { ret 42 }
	ret 0
}
