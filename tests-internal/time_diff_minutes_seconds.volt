package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	var a time.Time = time.Date(2024, 6, 15, 10, 0, 0, 0)
	var b time.Time = time.Date(2024, 6, 15, 10, 5, 30, 0)

	// b - a = 5 minutes 30 seconds = 330 seconds
	if time.DiffSeconds(b, a) == 330 { pass = pass + 1 }
	if time.DiffMinutes(b, a) == 5 { pass = pass + 1 }

	// Negative diff: a - b = -330 seconds, -5 minutes
	if time.DiffSeconds(a, b) == -330 { pass = pass + 1 }
	if time.DiffMinutes(a, b) == -5 { pass = pass + 1 }

	// Same time → 0.
	if time.DiffSeconds(a, a) == 0 { pass = pass + 1 }
	if time.DiffMinutes(a, a) == 0 { pass = pass + 1 }

	// Truncation: 59 seconds = 0 minutes.
	var c time.Time = time.Date(2024, 6, 15, 10, 0, 59, 0)
	if time.DiffMinutes(c, a) == 0 { pass = pass + 1 }
	if time.DiffSeconds(c, a) == 59 { pass = pass + 1 }

	// Cross-hour: 1 hour 30 min = 90 minutes
	var d time.Time = time.Date(2024, 6, 15, 11, 30, 0, 0)
	if time.DiffMinutes(d, a) == 90 { pass = pass + 1 }
	if time.DiffSeconds(d, a) == 5400 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 10 { ret 42 }
	ret 0
}
