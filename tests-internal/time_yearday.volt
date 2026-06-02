package main
import "log"
import "time"

// Positive test: (t Time).YearDay() — day of year (1-366).

fun main() int {
	var pass int = 0

	// Jan 1 → 1.
	var t1 time.Time = time.Date(2024, 1, 1, 0, 0, 0, 0)
	if t1.YearDay() == 1 { pass = pass + 1 }

	// Feb 1 → 32.
	var t2 time.Time = time.Date(2024, 2, 1, 0, 0, 0, 0)
	if t2.YearDay() == 32 { pass = pass + 1 }

	// Leap-year Feb 29 → 60.
	var t3 time.Time = time.Date(2024, 2, 29, 0, 0, 0, 0)
	if t3.YearDay() == 60 { pass = pass + 1 }

	// Non-leap Mar 1 (2023) → 60.
	var t4 time.Time = time.Date(2023, 3, 1, 0, 0, 0, 0)
	if t4.YearDay() == 60 { pass = pass + 1 }

	// Leap-year Mar 1 → 61.
	var t5 time.Time = time.Date(2024, 3, 1, 0, 0, 0, 0)
	if t5.YearDay() == 61 { pass = pass + 1 }

	// Dec 31 in leap year → 366.
	var t6 time.Time = time.Date(2024, 12, 31, 0, 0, 0, 0)
	if t6.YearDay() == 366 { pass = pass + 1 }

	// Dec 31 in non-leap year → 365.
	var t7 time.Time = time.Date(2023, 12, 31, 0, 0, 0, 0)
	if t7.YearDay() == 365 { pass = pass + 1 }

	// Mid-year.
	var t8 time.Time = time.Date(2024, 7, 4, 0, 0, 0, 0)
	if t8.YearDay() == 186 { pass = pass + 1 }   // 31+29+31+30+31+30+4 = 186

	// Today (2024-03-15) → 75.
	var t9 time.Time = time.Date(2024, 3, 15, 0, 0, 0, 0)
	if t9.YearDay() == 75 { pass = pass + 1 }

	// Pre-epoch: 1969-12-31 → 365.
	var t10 time.Time = time.Date(1969, 12, 31, 0, 0, 0, 0)
	if t10.YearDay() == 365 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 10 { ret 42 }
	ret 0
}
