package main
import "log"
import "time"

// Positive test: (t Time).Equal(u) + (t Time).IsLeapYear().

fun main() int {
	var pass int = 0

	// Equal: same instant.
	var t1 time.Time = time.Date(2024, 3, 15, 12, 0, 0, 0)
	var t2 time.Time = time.Date(2024, 3, 15, 12, 0, 0, 0)
	if t1.Equal(t2) { pass = pass + 1 }

	// Equal: different instant.
	var t3 time.Time = time.Date(2024, 3, 15, 12, 0, 0, 0)
	var t4 time.Time = time.Date(2024, 3, 15, 12, 0, 1, 0)
	if !t3.Equal(t4) { pass = pass + 1 }

	// Equal: very different.
	var t5 time.Time = time.Date(1970, 1, 1, 0, 0, 0, 0)
	var t6 time.Time = time.Date(2100, 12, 31, 23, 59, 59, 0)
	if !t5.Equal(t6) { pass = pass + 1 }

	// Equal: epoch == FromNano(0).
	var t7 time.Time = time.Date(1970, 1, 1, 0, 0, 0, 0)
	var t8 time.Time = time.FromNano(0)
	if t7.Equal(t8) { pass = pass + 1 }

	// IsLeapYear via method.
	var t9 time.Time = time.Date(2024, 3, 15, 0, 0, 0, 0)
	if t9.IsLeapYear() { pass = pass + 1 }

	var t10 time.Time = time.Date(2023, 3, 15, 0, 0, 0, 0)
	if !t10.IsLeapYear() { pass = pass + 1 }

	// Method matches the standalone function.
	var t11 time.Time = time.Date(2000, 1, 1, 0, 0, 0, 0)
	if t11.IsLeapYear() == time.IsLeapYear(2000) { pass = pass + 1 }

	var t12 time.Time = time.Date(1900, 1, 1, 0, 0, 0, 0)
	if t12.IsLeapYear() == time.IsLeapYear(1900) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 8 { ret 42 }
	ret 0
}
