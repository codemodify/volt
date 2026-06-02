package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// Jan 1 → day 1.
	if time.DayOfYear(time.Date(2026, 1, 1, 0, 0, 0, 0)) == 1 { pass = pass + 1 }

	// Jan 15 → day 15.
	if time.DayOfYear(time.Date(2026, 1, 15, 12, 0, 0, 0)) == 15 { pass = pass + 1 }

	// Jan 31 → day 31.
	if time.DayOfYear(time.Date(2026, 1, 31, 0, 0, 0, 0)) == 31 { pass = pass + 1 }

	// Feb 1 → day 32.
	if time.DayOfYear(time.Date(2026, 2, 1, 0, 0, 0, 0)) == 32 { pass = pass + 1 }

	// Feb 28 in non-leap year → day 59.
	if time.DayOfYear(time.Date(2026, 2, 28, 0, 0, 0, 0)) == 59 { pass = pass + 1 }

	// Mar 1 in non-leap year → day 60.
	if time.DayOfYear(time.Date(2026, 3, 1, 0, 0, 0, 0)) == 60 { pass = pass + 1 }

	// Feb 29 in leap year → day 60.
	if time.DayOfYear(time.Date(2024, 2, 29, 0, 0, 0, 0)) == 60 { pass = pass + 1 }

	// Mar 1 in leap year → day 61.
	if time.DayOfYear(time.Date(2024, 3, 1, 0, 0, 0, 0)) == 61 { pass = pass + 1 }

	// Dec 31 in non-leap year → day 365.
	if time.DayOfYear(time.Date(2026, 12, 31, 0, 0, 0, 0)) == 365 { pass = pass + 1 }

	// Dec 31 in leap year → day 366.
	if time.DayOfYear(time.Date(2024, 12, 31, 0, 0, 0, 0)) == 366 { pass = pass + 1 }

	// Mid-year sanity (Jun 30 non-leap = 31+28+31+30+31+30 = 181).
	if time.DayOfYear(time.Date(2026, 6, 30, 0, 0, 0, 0)) == 181 { pass = pass + 1 }

	// Mid-year sanity (Jul 4 non-leap = 31+28+31+30+31+30+4 = 185).
	if time.DayOfYear(time.Date(2026, 7, 4, 0, 0, 0, 0)) == 185 { pass = pass + 1 }

	// Time-of-day doesn't affect DayOfYear.
	if time.DayOfYear(time.Date(2026, 5, 28, 23, 59, 59, 0)) == time.DayOfYear(time.Date(2026, 5, 28, 0, 0, 0, 0)) { pass = pass + 1 }

	// Cross-property: DayOfYear of Jan 1 is always 1 regardless of year.
	if time.DayOfYear(time.Date(2000, 1, 1, 0, 0, 0, 0)) == 1 { pass = pass + 1 }
	if time.DayOfYear(time.Date(2100, 1, 1, 0, 0, 0, 0)) == 1 { pass = pass + 1 }

	// Cross-property: DayOfYear(end-of-year) == DaysInYear.
	var t1 time.Time = time.Date(2026, 12, 31, 0, 0, 0, 0)
	if time.DayOfYear(t1) == time.DaysInYear(2026) { pass = pass + 1 }
	var t2 time.Time = time.Date(2024, 12, 31, 0, 0, 0, 0)
	if time.DayOfYear(t2) == time.DaysInYear(2024) { pass = pass + 1 }

	// US Independence Day in 2024 (leap) is Jul 4 = 31+29+31+30+31+30+4 = 186.
	if time.DayOfYear(time.Date(2024, 7, 4, 0, 0, 0, 0)) == 186 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
