package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// 2026-05-28 Thursday → next is 2026-05-29 Friday.
	var thu time.Time = time.Date(2026, 5, 28, 12, 0, 0, 0)
	var nthu time.Time = time.NextWeekday(thu)
	if nthu.Day() == 29 { pass = pass + 1 }
	if nthu.Month() == 5 { pass = pass + 1 }

	// 2026-05-29 Friday → next is 2026-06-01 Monday.
	var fri time.Time = time.Date(2026, 5, 29, 12, 0, 0, 0)
	var nfri time.Time = time.NextWeekday(fri)
	if nfri.Day() == 1 { pass = pass + 1 }
	if nfri.Month() == 6 { pass = pass + 1 }

	// 2026-05-30 Saturday → next is 2026-06-01 Monday.
	var sat time.Time = time.Date(2026, 5, 30, 12, 0, 0, 0)
	var nsat time.Time = time.NextWeekday(sat)
	if nsat.Day() == 1 { pass = pass + 1 }
	if nsat.Month() == 6 { pass = pass + 1 }

	// 2026-05-31 Sunday → next is 2026-06-01 Monday.
	var sun time.Time = time.Date(2026, 5, 31, 12, 0, 0, 0)
	var nsun time.Time = time.NextWeekday(sun)
	if nsun.Day() == 1 { pass = pass + 1 }

	// 2026-06-01 Monday → next is 2026-06-02 Tuesday.
	var mon time.Time = time.Date(2026, 6, 1, 0, 0, 0, 0)
	var nmon time.Time = time.NextWeekday(mon)
	if nmon.Day() == 2 { pass = pass + 1 }

	// PrevWeekday tests.
	// 2026-06-01 Monday → prev is 2026-05-29 Friday.
	var mon2 time.Time = time.Date(2026, 6, 1, 12, 0, 0, 0)
	var pmon time.Time = time.PrevWeekday(mon2)
	if pmon.Day() == 29 { pass = pass + 1 }
	if pmon.Month() == 5 { pass = pass + 1 }

	// 2026-05-30 Saturday → prev is 2026-05-29 Friday.
	var sat2 time.Time = time.Date(2026, 5, 30, 12, 0, 0, 0)
	var psat time.Time = time.PrevWeekday(sat2)
	if psat.Day() == 29 { pass = pass + 1 }

	// 2026-05-31 Sunday → prev is 2026-05-29 Friday.
	var sun2 time.Time = time.Date(2026, 5, 31, 12, 0, 0, 0)
	var psun time.Time = time.PrevWeekday(sun2)
	if psun.Day() == 29 { pass = pass + 1 }

	// 2026-05-28 Thursday → prev is 2026-05-27 Wednesday.
	var thu2 time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	var pthu time.Time = time.PrevWeekday(thu2)
	if pthu.Day() == 27 { pass = pass + 1 }

	// Time-of-day preserved.
	var fri2 time.Time = time.Date(2026, 5, 29, 9, 30, 0, 0)
	var nfri2 time.Time = time.NextWeekday(fri2)
	if nfri2.Hour() == 9 { pass = pass + 1 }
	if nfri2.Minute() == 30 { pass = pass + 1 }

	// Result is always a weekday.
	var fri3 time.Time = time.Date(2026, 5, 29, 0, 0, 0, 0)
	var nfri3 time.Time = time.NextWeekday(fri3)
	if time.IsWeekday(nfri3) { pass = pass + 1 }
	var sat3 time.Time = time.Date(2026, 5, 30, 0, 0, 0, 0)
	var nsat3 time.Time = time.NextWeekday(sat3)
	if time.IsWeekday(nsat3) { pass = pass + 1 }

	// Next/prev are inverses on weekdays.
	var wed time.Time = time.Date(2026, 5, 27, 12, 0, 0, 0)
	var wedNext time.Time = time.NextWeekday(wed)
	var wedNextPrev time.Time = time.PrevWeekday(wedNext)
	if wedNextPrev.Day() == 27 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
