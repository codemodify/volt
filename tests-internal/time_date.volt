package main
import "log"
import "time"

// Positive test: time.Date constructor. Verify the produced Time
// round-trips through Format / accessors.

fun main() int {
	var pass int = 0

	// Epoch: 1970-01-01 00:00:00 UTC.
	var t0 time.Time = time.Date(1970, 1, 1, 0, 0, 0, 0)
	if t0.UnixNano() == 0 { pass = pass + 1 }

	// 2024-03-15 12:30:45 UTC.
	var t1 time.Time = time.Date(2024, 3, 15, 12, 30, 45, 0)
	if t1.Year() == 2024 { pass = pass + 1 }
	if t1.Month() == 3 { pass = pass + 1 }
	if t1.Day() == 15 { pass = pass + 1 }
	if t1.Hour() == 12 { pass = pass + 1 }
	if t1.Minute() == 30 { pass = pass + 1 }
	if t1.Second() == 45 { pass = pass + 1 }

	// Format roundtrip.
	var t2 time.Time = time.Date(2024, 3, 15, 12, 30, 45, 0)
	if t2.Format() == "2024-03-15T12:30:45Z" { pass = pass + 1 }

	// Pre-epoch date.
	var t3 time.Time = time.Date(1969, 12, 31, 23, 59, 59, 0)
	if t3.UnixNano() == -1000000000 { pass = pass + 1 }

	// Far future.
	var t4 time.Time = time.Date(2100, 12, 31, 23, 59, 59, 0)
	if t4.Year() == 2100 { pass = pass + 1 }
	if t4.Format() == "2100-12-31T23:59:59Z" { pass = pass + 1 }

	// Leap year: 2024-02-29.
	var t5 time.Time = time.Date(2024, 2, 29, 0, 0, 0, 0)
	if t5.Day() == 29 { pass = pass + 1 }
	if t5.Month() == 2 { pass = pass + 1 }

	// Sub-second nanos.
	var t6 time.Time = time.Date(2024, 1, 1, 0, 0, 0, 500000000)
	if t6.UnixNano() % 1000000000 == 500000000 { pass = pass + 1 }

	log.Println("pass=%d t2=%s", pass, t2.Format())
	if pass == 14 { ret 42 }
	ret 0
}
