package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// Start of minute: 2024-06-15 14:23:47.123456789 → 14:23:00.0
	var t time.Time = time.Date(2024, 6, 15, 14, 23, 47, 123456789)
	var s time.Time = time.StartOfMinute(t)
	if s.Hour() == 14 { pass = pass + 1 }
	if s.Minute() == 23 { pass = pass + 1 }
	if s.Second() == 0 { pass = pass + 1 }

	// End of minute: same → 14:23:59.999999999
	var e time.Time = time.EndOfMinute(t)
	if e.Hour() == 14 { pass = pass + 1 }
	if e.Minute() == 23 { pass = pass + 1 }
	if e.Second() == 59 { pass = pass + 1 }

	// Y/M/D preserved.
	var y int = 0
	var mo int = 0
	var d int = 0
	y, mo, d = s.YMD()
	if y == 2024 { pass = pass + 1 }
	if mo == 6 { pass = pass + 1 }
	if d == 15 { pass = pass + 1 }

	// At minute 0.
	var t2 time.Time = time.Date(2024, 6, 15, 14, 0, 0, 0)
	var s2 time.Time = time.StartOfMinute(t2)
	if s2.Minute() == 0 { pass = pass + 1 }
	if s2.Second() == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 11 { ret 42 }
	ret 0
}
