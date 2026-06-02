package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// UTCNow returns a non-zero Time in test environments where Now() returns wall-clock ns.
	var t time.Time = time.UTCNow()
	if t.UnixNano() > 0 { pass = pass + 1 }
	if t.Year() >= 2026 { pass = pass + 1 }

	// UTCNow.Unix() ≈ Now() / 1e9 (within 1s slack for clock drift).
	var nowSec int = time.Now() / 1000000000
	var ut time.Time = time.UTCNow()
	var diff int = ut.Unix() - nowSec
	if diff >= 0 { pass = pass + 1 }
	if diff <= 1 { pass = pass + 1 }

	// UTCNow equals FromNano(Now()) (modulo few-ns drift).
	// Both should produce Time values within 1ms of each other.
	var t1 time.Time = time.UTCNow()
	var t2 time.Time = time.FromNano(time.Now())
	var nsDrift int = t2.Sub(t1)
	if nsDrift >= 0 { pass = pass + 1 }
	if nsDrift < 1000000 { pass = pass + 1 }   // < 1ms

	// UTCNow.IsToday() matches Today().Year/Month/Day.
	var u time.Time = time.UTCNow()
	var d time.Time = time.Today()
	if u.Year() == d.Year() { pass = pass + 1 }
	if u.Month() == d.Month() { pass = pass + 1 }
	if u.Day() == d.Day() { pass = pass + 1 }

	// UTCNow.IsPast() is generally false (might briefly equal Now()).
	var z time.Time = time.UTCNow()
	if !z.IsFuture() { pass = pass + 1 }

	// UTCNow.IsToday() — true by construction.
	var w time.Time = time.UTCNow()
	if w.IsToday() { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 11 { ret 42 }
	ret 0
}
