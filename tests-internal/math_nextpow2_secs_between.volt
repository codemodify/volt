package main
import "log"
import "math"
import "time"

// Positive test: math.NextPow2 + (t Time).SecondsBetween.

fun main() int {
	var pass int = 0

	// NextPow2 — exact powers passthrough.
	if math.NextPow2(1) == 1 { pass = pass + 1 }
	if math.NextPow2(2) == 2 { pass = pass + 1 }
	if math.NextPow2(4) == 4 { pass = pass + 1 }
	if math.NextPow2(1024) == 1024 { pass = pass + 1 }
	if math.NextPow2(65536) == 65536 { pass = pass + 1 }

	// NextPow2 — round up.
	if math.NextPow2(3) == 4 { pass = pass + 1 }
	if math.NextPow2(5) == 8 { pass = pass + 1 }
	if math.NextPow2(9) == 16 { pass = pass + 1 }
	if math.NextPow2(100) == 128 { pass = pass + 1 }
	if math.NextPow2(1000) == 1024 { pass = pass + 1 }

	// NextPow2 — n <= 1 returns 1.
	if math.NextPow2(0) == 1 { pass = pass + 1 }
	if math.NextPow2(-1) == 1 { pass = pass + 1 }
	if math.NextPow2(-1000) == 1 { pass = pass + 1 }

	// NextPow2 — overflow guard.
	var huge int = 1 << 62
	if math.NextPow2(huge) == huge { pass = pass + 1 }
	if math.NextPow2(huge + 1) == 0 { pass = pass + 1 }

	// SecondsBetween — basic.
	var t1 time.Time = time.Date(2024, 3, 15, 12, 0, 0, 0)
	var t2 time.Time = time.Date(2024, 3, 15, 12, 0, 0, 0)
	if t1.SecondsBetween(t2) == 0 { pass = pass + 1 }

	// +1 second.
	var t3 time.Time = time.Date(2024, 3, 15, 12, 0, 1, 0)
	if t3.SecondsBetween(t1) == 1 { pass = pass + 1 }

	// +60 seconds = +1 minute.
	var t4 time.Time = time.Date(2024, 3, 15, 12, 1, 0, 0)
	if t4.SecondsBetween(t1) == 60 { pass = pass + 1 }

	// +3600 seconds = +1 hour.
	var t5 time.Time = time.Date(2024, 3, 15, 13, 0, 0, 0)
	if t5.SecondsBetween(t1) == 3600 { pass = pass + 1 }

	// +86400 seconds = +1 day.
	var t6 time.Time = time.Date(2024, 3, 16, 12, 0, 0, 0)
	if t6.SecondsBetween(t1) == 86400 { pass = pass + 1 }

	// Negative direction.
	if t1.SecondsBetween(t3) == -1 { pass = pass + 1 }

	// Sub-second floor-div quantizes to 0.
	var t7 time.Time = time.Date(2024, 3, 15, 12, 0, 0, 500000000)   // +500ms
	if t7.SecondsBetween(t1) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
