package main
import "log"
import "time"

// Positive test: (t Time).WithTime + WithDate.

fun main() int {
	var pass int = 0

	// WithTime — keeps date, swaps time.
	var t1 time.Time = time.Date(2024, 6, 15, 9, 30, 0, 0)
	var noon time.Time = t1.WithTime(12, 0, 0)
	if noon.Year() == 2024 { pass = pass + 1 }
	if noon.Month() == 6 { pass = pass + 1 }
	if noon.Day() == 15 { pass = pass + 1 }
	if noon.Hour() == 12 { pass = pass + 1 }
	if noon.Minute() == 0 { pass = pass + 1 }
	if noon.Second() == 0 { pass = pass + 1 }

	// WithTime — to midnight.
	var mid time.Time = t1.WithTime(0, 0, 0)
	if mid.Day() == 15 { pass = pass + 1 }
	if mid.Hour() == 0 { pass = pass + 1 }

	// WithTime — to last second.
	var lastSec time.Time = t1.WithTime(23, 59, 59)
	if lastSec.Hour() == 23 { pass = pass + 1 }
	if lastSec.Second() == 59 { pass = pass + 1 }

	// WithDate — keeps time, swaps date.
	var withDate time.Time = t1.WithDate(2025, 12, 31)
	if withDate.Year() == 2025 { pass = pass + 1 }
	if withDate.Month() == 12 { pass = pass + 1 }
	if withDate.Day() == 31 { pass = pass + 1 }
	if withDate.Hour() == 9 { pass = pass + 1 }
	if withDate.Minute() == 30 { pass = pass + 1 }

	// WithDate — to leap day.
	var leap time.Time = t1.WithDate(2024, 2, 29)
	if leap.Year() == 2024 { pass = pass + 1 }
	if leap.Month() == 2 { pass = pass + 1 }
	if leap.Day() == 29 { pass = pass + 1 }
	if leap.Hour() == 9 { pass = pass + 1 }

	// WithTime followed by WithDate composes.
	var roundtrip time.Time = t1.WithTime(15, 30, 45).WithDate(2025, 1, 1)
	if roundtrip.Year() == 2025 { pass = pass + 1 }
	if roundtrip.Hour() == 15 { pass = pass + 1 }
	if roundtrip.Minute() == 30 { pass = pass + 1 }

	// WithDate preserves the existing time including seconds.
	var withSec time.Time = time.Date(2024, 6, 15, 9, 30, 45, 0)
	var moved time.Time = withSec.WithDate(2025, 6, 15)
	if moved.Year() == 2025 { pass = pass + 1 }
	if moved.Second() == 45 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
