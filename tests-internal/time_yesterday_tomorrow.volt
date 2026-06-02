package main
import "log"
import "time"

// Positive test: (t Time).Yesterday + (t Time).Tomorrow.

fun main() int {
	var pass int = 0

	// Basic — mid-month.
	var t1 time.Time = time.Date(2024, 6, 15, 12, 30, 45, 0)
	var y1 time.Time = t1.Yesterday()
	if y1.Year() == 2024 { pass = pass + 1 }
	if y1.Month() == 6 { pass = pass + 1 }
	if y1.Day() == 14 { pass = pass + 1 }

	var tm1 time.Time = t1.Tomorrow()
	if tm1.Year() == 2024 { pass = pass + 1 }
	if tm1.Month() == 6 { pass = pass + 1 }
	if tm1.Day() == 16 { pass = pass + 1 }

	// Wall-clock time preserved.
	if y1.Hour() == 12 { pass = pass + 1 }
	if tm1.Hour() == 12 { pass = pass + 1 }

	// Month boundary — Jan 1 yesterday is Dec 31 of prior year.
	var t2 time.Time = time.Date(2024, 1, 1, 0, 0, 0, 0)
	var y2 time.Time = t2.Yesterday()
	if y2.Year() == 2023 { pass = pass + 1 }
	if y2.Month() == 12 { pass = pass + 1 }
	if y2.Day() == 31 { pass = pass + 1 }

	// Month boundary — Dec 31 tomorrow is Jan 1 of next year.
	var t3 time.Time = time.Date(2024, 12, 31, 0, 0, 0, 0)
	var tm3 time.Time = t3.Tomorrow()
	if tm3.Year() == 2025 { pass = pass + 1 }
	if tm3.Month() == 1 { pass = pass + 1 }
	if tm3.Day() == 1 { pass = pass + 1 }

	// Leap day — Feb 29 2024 tomorrow is Mar 1 2024.
	var t4 time.Time = time.Date(2024, 2, 29, 0, 0, 0, 0)
	var tm4 time.Time = t4.Tomorrow()
	if tm4.Month() == 3 { pass = pass + 1 }
	if tm4.Day() == 1 { pass = pass + 1 }

	// Mar 1 2024 yesterday is Feb 29 2024 (leap year).
	var t5 time.Time = time.Date(2024, 3, 1, 0, 0, 0, 0)
	var y5 time.Time = t5.Yesterday()
	if y5.Month() == 2 { pass = pass + 1 }
	if y5.Day() == 29 { pass = pass + 1 }

	// Non-leap year — Mar 1 2023 yesterday is Feb 28 2023.
	var t6 time.Time = time.Date(2023, 3, 1, 0, 0, 0, 0)
	var y6 time.Time = t6.Yesterday()
	if y6.Month() == 2 { pass = pass + 1 }
	if y6.Day() == 28 { pass = pass + 1 }

	// Inverse: Tomorrow.Yesterday == original day.
	var t7 time.Time = time.Date(2024, 7, 15, 9, 0, 0, 0)
	var back time.Time = t7.Tomorrow().Yesterday()
	if back.Year() == 2024 { pass = pass + 1 }
	if back.Month() == 7 { pass = pass + 1 }
	if back.Day() == 15 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
