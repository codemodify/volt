package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// 2024-06-14 is Friday.
	var fri time.Time = time.Date(2024, 6, 14, 12, 0, 0, 0)

	// AddBusinessDays — 1 business day from Fri → Mon (skip weekend).
	var monNext time.Time = fri.AddBusinessDays(1)
	if monNext.Day() == 17 { pass = pass + 1 }
	if monNext.Weekday() == 1 { pass = pass + 1 }
	if monNext.Hour() == 12 { pass = pass + 1 }

	// AddBusinessDays — 5 business days from Fri = next Fri.
	var nextFri time.Time = fri.AddBusinessDays(5)
	if nextFri.Day() == 21 { pass = pass + 1 }
	if nextFri.Weekday() == 5 { pass = pass + 1 }

	// AddBusinessDays — 0 returns same instant.
	var same time.Time = fri.AddBusinessDays(0)
	if same.Sub(fri) == 0 { pass = pass + 1 }

	// AddBusinessDays — negative goes backward.
	var prevThu time.Time = fri.AddBusinessDays(-1)
	if prevThu.Day() == 13 { pass = pass + 1 }
	if prevThu.Weekday() == 4 { pass = pass + 1 }

	// AddBusinessDays — -5 from Fri = prev Fri.
	var prevFri time.Time = fri.AddBusinessDays(-5)
	if prevFri.Day() == 7 { pass = pass + 1 }

	// AddBusinessDays — from Saturday, +1 = Monday.
	var sat time.Time = time.Date(2024, 6, 15, 0, 0, 0, 0)
	var monAfterSat time.Time = sat.AddBusinessDays(1)
	if monAfterSat.Day() == 17 { pass = pass + 1 }

	// BusinessDaysBetween — Fri to next Fri = 5 business days.
	if nextFri.BusinessDaysBetween(fri) == 5 { pass = pass + 1 }

	// BusinessDaysBetween — same day = 0.
	if fri.BusinessDaysBetween(fri) == 0 { pass = pass + 1 }

	// BusinessDaysBetween — Fri → Mon = 1 business day.
	var mon time.Time = time.Date(2024, 6, 17, 12, 0, 0, 0)
	if mon.BusinessDaysBetween(fri) == 1 { pass = pass + 1 }

	// BusinessDaysBetween — Mon → Fri (backward) = -1.
	if fri.BusinessDaysBetween(mon) == -1 { pass = pass + 1 }

	// BusinessDaysBetween — Mon → following Mon = 5.
	var nextMon time.Time = time.Date(2024, 6, 24, 12, 0, 0, 0)
	if nextMon.BusinessDaysBetween(mon) == 5 { pass = pass + 1 }

	// AddBusinessDays roundtrip: AddBusinessDays(n) then AddBusinessDays(-n) returns to same day.
	var fwdBack time.Time = fri.AddBusinessDays(7).AddBusinessDays(-7)
	if fwdBack.DaysBetween(fri) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
