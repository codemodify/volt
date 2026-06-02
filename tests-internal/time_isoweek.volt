package main
import "log"
import "time"

// Positive test: time.ISOWeek + time.ISOWeekYear.

fun main() int {
	var pass int = 0

	// 2024-01-01 is a Monday → week 1 of ISO 2024.
	var t1 time.Time = time.Date(2024, 1, 1, 0, 0, 0, 0)
	if t1.ISOWeek() == 1 { pass = pass + 1 }
	if t1.ISOWeekYear() == 2024 { pass = pass + 1 }

	// 2024-12-30 is a Monday → week 1 of ISO 2025 (next-year case).
	var t2 time.Time = time.Date(2024, 12, 30, 0, 0, 0, 0)
	if t2.ISOWeek() == 1 { pass = pass + 1 }
	if t2.ISOWeekYear() == 2025 { pass = pass + 1 }

	// 2021-01-01 is a Friday → week 53 of ISO 2020 (prior-year case).
	var t3 time.Time = time.Date(2021, 1, 1, 0, 0, 0, 0)
	if t3.ISOWeek() == 53 { pass = pass + 1 }
	if t3.ISOWeekYear() == 2020 { pass = pass + 1 }

	// 2022-01-01 is a Saturday → week 52 of ISO 2021.
	var t4 time.Time = time.Date(2022, 1, 1, 0, 0, 0, 0)
	if t4.ISOWeek() == 52 { pass = pass + 1 }
	if t4.ISOWeekYear() == 2021 { pass = pass + 1 }

	// 2023-01-01 is a Sunday → week 52 of ISO 2022.
	var t5 time.Time = time.Date(2023, 1, 1, 0, 0, 0, 0)
	if t5.ISOWeek() == 52 { pass = pass + 1 }
	if t5.ISOWeekYear() == 2022 { pass = pass + 1 }

	// 2020-01-01 is a Wednesday → week 1 of ISO 2020.
	var t6 time.Time = time.Date(2020, 1, 1, 0, 0, 0, 0)
	if t6.ISOWeek() == 1 { pass = pass + 1 }
	if t6.ISOWeekYear() == 2020 { pass = pass + 1 }

	// 2026-01-01 is a Thursday → week 1 of ISO 2026.
	var t7 time.Time = time.Date(2026, 1, 1, 0, 0, 0, 0)
	if t7.ISOWeek() == 1 { pass = pass + 1 }
	if t7.ISOWeekYear() == 2026 { pass = pass + 1 }

	// 2026-12-31 is a Thursday → week 53 of ISO 2026 (53-week year).
	var t8 time.Time = time.Date(2026, 12, 31, 0, 0, 0, 0)
	if t8.ISOWeek() == 53 { pass = pass + 1 }
	if t8.ISOWeekYear() == 2026 { pass = pass + 1 }

	// 2027-01-01 is a Friday → week 53 of ISO 2026 (overflow into next).
	var t9 time.Time = time.Date(2027, 1, 1, 0, 0, 0, 0)
	if t9.ISOWeek() == 53 { pass = pass + 1 }
	if t9.ISOWeekYear() == 2026 { pass = pass + 1 }

	// Mid-year — exact week match. 2024-07-15 is a Monday.
	// 2024-01-01 (Mon) is week 1. Days = 196. 196/7 = 28, week 29.
	var t10 time.Time = time.Date(2024, 7, 15, 0, 0, 0, 0)
	if t10.ISOWeek() == 29 { pass = pass + 1 }
	if t10.ISOWeekYear() == 2024 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
