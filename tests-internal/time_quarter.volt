package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// QuarterOf for each month.
	if time.QuarterOf(time.Date(2026, 1, 15, 0, 0, 0, 0)) == 1 { pass = pass + 1 }
	if time.QuarterOf(time.Date(2026, 2, 15, 0, 0, 0, 0)) == 1 { pass = pass + 1 }
	if time.QuarterOf(time.Date(2026, 3, 15, 0, 0, 0, 0)) == 1 { pass = pass + 1 }
	if time.QuarterOf(time.Date(2026, 4, 15, 0, 0, 0, 0)) == 2 { pass = pass + 1 }
	if time.QuarterOf(time.Date(2026, 5, 15, 0, 0, 0, 0)) == 2 { pass = pass + 1 }
	if time.QuarterOf(time.Date(2026, 6, 15, 0, 0, 0, 0)) == 2 { pass = pass + 1 }
	if time.QuarterOf(time.Date(2026, 7, 15, 0, 0, 0, 0)) == 3 { pass = pass + 1 }
	if time.QuarterOf(time.Date(2026, 9, 15, 0, 0, 0, 0)) == 3 { pass = pass + 1 }
	if time.QuarterOf(time.Date(2026, 10, 15, 0, 0, 0, 0)) == 4 { pass = pass + 1 }
	if time.QuarterOf(time.Date(2026, 12, 15, 0, 0, 0, 0)) == 4 { pass = pass + 1 }

	// StartOfQuarter for Q1.
	var t1 time.Time = time.Date(2026, 2, 15, 14, 30, 0, 0)
	var sq1 time.Time = time.StartOfQuarter(t1)
	if sq1.Year() == 2026 { pass = pass + 1 }
	if sq1.Month() == 1 { pass = pass + 1 }
	if sq1.Day() == 1 { pass = pass + 1 }
	if sq1.Hour() == 0 { pass = pass + 1 }

	// StartOfQuarter for Q2.
	var t2 time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	var sq2 time.Time = time.StartOfQuarter(t2)
	if sq2.Month() == 4 { pass = pass + 1 }
	if sq2.Day() == 1 { pass = pass + 1 }

	// StartOfQuarter for Q3.
	var t3 time.Time = time.Date(2026, 8, 1, 0, 0, 0, 0)
	var sq3 time.Time = time.StartOfQuarter(t3)
	if sq3.Month() == 7 { pass = pass + 1 }

	// StartOfQuarter for Q4.
	var t4 time.Time = time.Date(2026, 11, 30, 0, 0, 0, 0)
	var sq4 time.Time = time.StartOfQuarter(t4)
	if sq4.Month() == 10 { pass = pass + 1 }

	// EndOfQuarter for Q1 → Mar 31.
	var t5 time.Time = time.Date(2026, 2, 15, 0, 0, 0, 0)
	var eq1 time.Time = time.EndOfQuarter(t5)
	if eq1.Month() == 3 { pass = pass + 1 }
	if eq1.Day() == 31 { pass = pass + 1 }
	if eq1.Hour() == 23 { pass = pass + 1 }

	// EndOfQuarter for Q2 → Jun 30.
	var t6 time.Time = time.Date(2026, 5, 15, 0, 0, 0, 0)
	var eq2 time.Time = time.EndOfQuarter(t6)
	if eq2.Month() == 6 { pass = pass + 1 }
	if eq2.Day() == 30 { pass = pass + 1 }

	// EndOfQuarter for Q3 → Sep 30.
	var t7 time.Time = time.Date(2026, 8, 15, 0, 0, 0, 0)
	var eq3 time.Time = time.EndOfQuarter(t7)
	if eq3.Month() == 9 { pass = pass + 1 }
	if eq3.Day() == 30 { pass = pass + 1 }

	// EndOfQuarter for Q4 → Dec 31.
	var t8 time.Time = time.Date(2026, 11, 15, 0, 0, 0, 0)
	var eq4 time.Time = time.EndOfQuarter(t8)
	if eq4.Month() == 12 { pass = pass + 1 }
	if eq4.Day() == 31 { pass = pass + 1 }

	// Idempotence.
	var t9 time.Time = time.Date(2026, 1, 1, 0, 0, 0, 0)
	var sq9 time.Time = time.StartOfQuarter(t9)
	if sq9.Month() == 1 { pass = pass + 1 }
	if sq9.Day() == 1 { pass = pass + 1 }

	// Quarterly report range query.
	var event time.Time = time.Date(2026, 5, 15, 12, 0, 0, 0)
	var qLo time.Time = time.StartOfQuarter(event)
	var event2 time.Time = time.Date(2026, 5, 15, 12, 0, 0, 0)
	var qHi time.Time = time.EndOfQuarter(event2)
	var ev3 time.Time = time.Date(2026, 5, 15, 12, 0, 0, 0)
	if time.TimeIsBetween(ev3, qLo, qHi) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 30 { ret 42 }
	ret 0
}
