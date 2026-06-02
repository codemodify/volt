package main
import "log"
import "time"

// Positive test: (t Time).DaysInThisMonth + DaysInYear + (t Time).DaysInThisYear.

fun main() int {
	var pass int = 0

	// DaysInThisMonth — 31-day month.
	var may time.Time = time.Date(2024, 5, 15, 0, 0, 0, 0)
	if may.DaysInThisMonth() == 31 { pass = pass + 1 }

	// 30-day month.
	var apr time.Time = time.Date(2024, 4, 15, 0, 0, 0, 0)
	if apr.DaysInThisMonth() == 30 { pass = pass + 1 }

	// February leap year.
	var feb2024 time.Time = time.Date(2024, 2, 15, 0, 0, 0, 0)
	if feb2024.DaysInThisMonth() == 29 { pass = pass + 1 }

	// February non-leap.
	var feb2023 time.Time = time.Date(2023, 2, 15, 0, 0, 0, 0)
	if feb2023.DaysInThisMonth() == 28 { pass = pass + 1 }

	// February century non-leap (1900).
	var feb1900 time.Time = time.Date(1900, 2, 15, 0, 0, 0, 0)
	if feb1900.DaysInThisMonth() == 28 { pass = pass + 1 }

	// February 400-multiple leap (2000).
	var feb2000 time.Time = time.Date(2000, 2, 15, 0, 0, 0, 0)
	if feb2000.DaysInThisMonth() == 29 { pass = pass + 1 }

	// Dec → 31 days.
	var dec time.Time = time.Date(2024, 12, 31, 23, 59, 59, 0)
	if dec.DaysInThisMonth() == 31 { pass = pass + 1 }

	// DaysInYear — free function.
	if time.DaysInYear(2024) == 366 { pass = pass + 1 }
	if time.DaysInYear(2023) == 365 { pass = pass + 1 }
	if time.DaysInYear(2000) == 366 { pass = pass + 1 }
	if time.DaysInYear(1900) == 365 { pass = pass + 1 }

	// DaysInThisYear — method.
	if feb2024.DaysInThisYear() == 366 { pass = pass + 1 }
	if feb2023.DaysInThisYear() == 365 { pass = pass + 1 }

	// Sum across all months equals DaysInYear.
	var totalLeap int = 0
	for m := 1; m <= 12; m++ {
		totalLeap = totalLeap + time.DaysInMonth(2024, m)
	}
	if totalLeap == 366 { pass = pass + 1 }

	var totalNonLeap int = 0
	for m := 1; m <= 12; m++ {
		totalNonLeap = totalNonLeap + time.DaysInMonth(2023, m)
	}
	if totalNonLeap == 365 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
