package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// 2024-06-14 is Friday.
	var fri time.Time = time.Date(2024, 6, 14, 12, 0, 0, 0)

	// 2024-06-15 is Saturday.
	// 2024-06-16 is Sunday.
	// 2024-06-17 is Monday.

	// NextBusinessDay — Friday → Monday.
	var monAfter time.Time = fri.NextBusinessDay()
	if monAfter.Day() == 17 { pass = pass + 1 }
	if monAfter.Weekday() == 1 { pass = pass + 1 }   // Monday
	if monAfter.Hour() == 12 { pass = pass + 1 }     // wall-clock preserved

	// NextBusinessDay from Saturday → Monday.
	var sat time.Time = time.Date(2024, 6, 15, 0, 0, 0, 0)
	var afterSat time.Time = sat.NextBusinessDay()
	if afterSat.Day() == 17 { pass = pass + 1 }

	// NextBusinessDay from Sunday → Monday.
	var sun time.Time = time.Date(2024, 6, 16, 0, 0, 0, 0)
	var afterSun time.Time = sun.NextBusinessDay()
	if afterSun.Day() == 17 { pass = pass + 1 }

	// NextBusinessDay from Mon → Tue.
	var mon time.Time = time.Date(2024, 6, 17, 0, 0, 0, 0)
	var tue time.Time = mon.NextBusinessDay()
	if tue.Day() == 18 { pass = pass + 1 }
	if tue.Weekday() == 2 { pass = pass + 1 }

	// PrevBusinessDay — Monday → Friday.
	var friBefore time.Time = mon.PrevBusinessDay()
	if friBefore.Day() == 14 { pass = pass + 1 }
	if friBefore.Weekday() == 5 { pass = pass + 1 }

	// PrevBusinessDay from Saturday → Friday.
	var prevFri time.Time = sat.PrevBusinessDay()
	if prevFri.Day() == 14 { pass = pass + 1 }

	// PrevBusinessDay from Sunday → Friday.
	var prevFri2 time.Time = sun.PrevBusinessDay()
	if prevFri2.Day() == 14 { pass = pass + 1 }

	// PrevBusinessDay from Tue → Mon.
	var tue2 time.Time = time.Date(2024, 6, 18, 0, 0, 0, 0)
	var prevMon time.Time = tue2.PrevBusinessDay()
	if prevMon.Day() == 17 { pass = pass + 1 }

	// All NextBusinessDay results are weekdays.
	if monAfter.IsWeekday() { pass = pass + 1 }
	if afterSat.IsWeekday() { pass = pass + 1 }
	if afterSun.IsWeekday() { pass = pass + 1 }

	// All PrevBusinessDay results are weekdays.
	if friBefore.IsWeekday() { pass = pass + 1 }
	if prevFri.IsWeekday() { pass = pass + 1 }

	// NextBusinessDay across month boundary.
	// 2024-05-31 is Friday. NextBusinessDay → 2024-06-03 (Monday).
	var endMay time.Time = time.Date(2024, 5, 31, 0, 0, 0, 0)
	var startJune time.Time = endMay.NextBusinessDay()
	if startJune.Month() == 6 { pass = pass + 1 }
	if startJune.Day() == 3 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
