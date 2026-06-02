package main
import "log"
import "time"

// Positive test: (t Time).StartOfWeek + (t Time).EndOfWeek.

fun main() int {
	var pass int = 0

	// 2024-06-12 is a Wednesday → StartOfWeek = Monday 2024-06-10, EndOfWeek = Sunday 2024-06-16.
	var wed time.Time = time.Date(2024, 6, 12, 15, 30, 0, 0)
	var startW time.Time = wed.StartOfWeek()
	if startW.Year() == 2024 { pass = pass + 1 }
	if startW.Month() == 6 { pass = pass + 1 }
	if startW.Day() == 10 { pass = pass + 1 }
	if startW.Hour() == 0 { pass = pass + 1 }
	if startW.Minute() == 0 { pass = pass + 1 }
	if startW.Second() == 0 { pass = pass + 1 }

	var endW time.Time = wed.EndOfWeek()
	if endW.Year() == 2024 { pass = pass + 1 }
	if endW.Month() == 6 { pass = pass + 1 }
	if endW.Day() == 16 { pass = pass + 1 }
	if endW.Hour() == 23 { pass = pass + 1 }
	if endW.Minute() == 59 { pass = pass + 1 }
	if endW.Second() == 59 { pass = pass + 1 }

	// Monday should StartOfWeek to itself (at midnight).
	var mon time.Time = time.Date(2024, 6, 10, 10, 0, 0, 0)
	var sm time.Time = mon.StartOfWeek()
	if sm.Day() == 10 { pass = pass + 1 }
	if sm.Hour() == 0 { pass = pass + 1 }

	// Sunday should EndOfWeek to itself (at 23:59:59).
	var sun time.Time = time.Date(2024, 6, 16, 10, 0, 0, 0)
	var es time.Time = sun.EndOfWeek()
	if es.Day() == 16 { pass = pass + 1 }
	if es.Hour() == 23 { pass = pass + 1 }

	// Sunday should StartOfWeek to previous Monday (6 days back).
	var ss time.Time = sun.StartOfWeek()
	if ss.Day() == 10 { pass = pass + 1 }

	// Monday should EndOfWeek to following Sunday (6 days forward).
	var em time.Time = mon.EndOfWeek()
	if em.Day() == 16 { pass = pass + 1 }

	// Week boundary across months: 2024-04-29 is a Monday →
	// EndOfWeek = Sunday 2024-05-05 (month rolls forward).
	var apr29 time.Time = time.Date(2024, 4, 29, 0, 0, 0, 0)
	var e1 time.Time = apr29.EndOfWeek()
	if e1.Month() == 5 { pass = pass + 1 }
	if e1.Day() == 5 { pass = pass + 1 }

	// Week boundary across years: 2024-12-31 is a Tuesday →
	// StartOfWeek = Monday 2024-12-30, EndOfWeek = Sunday 2025-01-05.
	var dec31 time.Time = time.Date(2024, 12, 31, 12, 0, 0, 0)
	var s2 time.Time = dec31.StartOfWeek()
	if s2.Year() == 2024 { pass = pass + 1 }
	if s2.Day() == 30 { pass = pass + 1 }
	var e2 time.Time = dec31.EndOfWeek()
	if e2.Year() == 2025 { pass = pass + 1 }
	if e2.Month() == 1 { pass = pass + 1 }
	if e2.Day() == 5 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 25 { ret 42 }
	ret 0
}
