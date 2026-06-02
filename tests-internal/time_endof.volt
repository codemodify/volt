package main
import "log"
import "time"

// Positive test: (t Time).EndOfMonth + EndOfYear.

fun main() int {
	var pass int = 0

	// March has 31 days.
	var march time.Time = time.Date(2024, 3, 15, 12, 0, 0, 0)
	var em time.Time = march.EndOfMonth()
	if em.Year() == 2024 { pass = pass + 1 }
	if em.Month() == 3 { pass = pass + 1 }
	if em.Day() == 31 { pass = pass + 1 }
	if em.Hour() == 23 { pass = pass + 1 }
	if em.Minute() == 59 { pass = pass + 1 }
	if em.Second() == 59 { pass = pass + 1 }

	// February 2024 (leap) has 29 days.
	var feb24 time.Time = time.Date(2024, 2, 15, 0, 0, 0, 0)
	var emFeb24 time.Time = feb24.EndOfMonth()
	if emFeb24.Day() == 29 { pass = pass + 1 }
	if emFeb24.Month() == 2 { pass = pass + 1 }

	// February 2023 (non-leap) has 28 days.
	var feb23 time.Time = time.Date(2023, 2, 15, 0, 0, 0, 0)
	var emFeb23 time.Time = feb23.EndOfMonth()
	if emFeb23.Day() == 28 { pass = pass + 1 }

	// April has 30 days.
	var apr time.Time = time.Date(2024, 4, 10, 0, 0, 0, 0)
	var emApr time.Time = apr.EndOfMonth()
	if emApr.Day() == 30 { pass = pass + 1 }

	// December has 31 days.
	var dec time.Time = time.Date(2024, 12, 5, 0, 0, 0, 0)
	var emDec time.Time = dec.EndOfMonth()
	if emDec.Day() == 31 { pass = pass + 1 }
	if emDec.Month() == 12 { pass = pass + 1 }

	// EndOfYear — Dec 31, 23:59:59.
	var t time.Time = time.Date(2024, 3, 15, 0, 0, 0, 0)
	var ey time.Time = t.EndOfYear()
	if ey.Year() == 2024 { pass = pass + 1 }
	if ey.Month() == 12 { pass = pass + 1 }
	if ey.Day() == 31 { pass = pass + 1 }
	if ey.Hour() == 23 { pass = pass + 1 }

	// EndOfYear from December — still ends Dec 31 same year.
	var lateInYear time.Time = time.Date(2024, 12, 31, 0, 0, 0, 0)
	var eyLate time.Time = lateInYear.EndOfYear()
	if eyLate.Month() == 12 { pass = pass + 1 }
	if eyLate.Day() == 31 { pass = pass + 1 }
	if eyLate.Year() == 2024 { pass = pass + 1 }

	// EndOfMonth and StartOfMonth bookend the month (same month/year).
	var midMonth time.Time = time.Date(2024, 7, 15, 0, 0, 0, 0)
	if midMonth.StartOfMonth().IsSameMonth(midMonth.EndOfMonth()) { pass = pass + 1 }

	// EndOfDay is on the same day as EndOfMonth's day.
	if midMonth.EndOfMonth().IsSameDay(midMonth.EndOfMonth().EndOfDay()) { pass = pass + 1 }

	// January EndOfMonth.
	var jan time.Time = time.Date(2024, 1, 1, 0, 0, 0, 0)
	var emJan time.Time = jan.EndOfMonth()
	if emJan.Day() == 31 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
