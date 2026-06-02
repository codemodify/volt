package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// Jan 1 → week 1.
	var t1 time.Time = time.Date(2024, 1, 1, 0, 0, 0, 0)
	if time.WeekOfYear(t1) == 1 { pass = pass + 1 }

	// Jan 7 → still week 1.
	var t2 time.Time = time.Date(2024, 1, 7, 0, 0, 0, 0)
	if time.WeekOfYear(t2) == 1 { pass = pass + 1 }

	// Jan 8 → week 2.
	var t3 time.Time = time.Date(2024, 1, 8, 0, 0, 0, 0)
	if time.WeekOfYear(t3) == 2 { pass = pass + 1 }

	// Jan 14 → week 2 still.
	var t4 time.Time = time.Date(2024, 1, 14, 0, 0, 0, 0)
	if time.WeekOfYear(t4) == 2 { pass = pass + 1 }

	// Jan 15 → week 3.
	var t5 time.Time = time.Date(2024, 1, 15, 0, 0, 0, 0)
	if time.WeekOfYear(t5) == 3 { pass = pass + 1 }

	// Mid-year: July 1 2024 is day 183 → week 27.
	var t6 time.Time = time.Date(2024, 7, 1, 0, 0, 0, 0)
	if time.WeekOfYear(t6) == 27 { pass = pass + 1 }

	// Dec 31 leap year (2024): day 366 → week 53.
	var t7 time.Time = time.Date(2024, 12, 31, 0, 0, 0, 0)
	if time.WeekOfYear(t7) == 53 { pass = pass + 1 }

	// Dec 31 non-leap (2023): day 365 → week 53.
	var t8 time.Time = time.Date(2023, 12, 31, 0, 0, 0, 0)
	if time.WeekOfYear(t8) == 53 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 8 { ret 42 }
	ret 0
}
