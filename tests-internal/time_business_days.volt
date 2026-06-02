package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// n=0 → unchanged.
	var t0 time.Time = time.Date(2026, 5, 28, 12, 0, 0, 0)
	var r0 time.Time = time.AddBusinessDays(t0, 0)
	if r0.Day() == 28 { pass = pass + 1 }

	// Mon → Tue (+1).
	// 2026-06-01 Monday → 2026-06-02 Tuesday.
	var mon time.Time = time.Date(2026, 6, 1, 0, 0, 0, 0)
	var nbm time.Time = time.AddBusinessDays(mon, 1)
	if nbm.Day() == 2 { pass = pass + 1 }
	if nbm.Month() == 6 { pass = pass + 1 }

	// Thu → Fri (+1).
	var thu time.Time = time.Date(2026, 5, 28, 12, 0, 0, 0)
	var nthu time.Time = time.AddBusinessDays(thu, 1)
	if nthu.Day() == 29 { pass = pass + 1 }

	// Fri → next Mon (+1 skips weekend).
	var fri time.Time = time.Date(2026, 5, 29, 12, 0, 0, 0)
	var nfri time.Time = time.AddBusinessDays(fri, 1)
	if nfri.Day() == 1 { pass = pass + 1 }
	if nfri.Month() == 6 { pass = pass + 1 }

	// Fri → +5 business days = next Fri.
	var fri2 time.Time = time.Date(2026, 5, 29, 12, 0, 0, 0)
	var nfri5 time.Time = time.AddBusinessDays(fri2, 5)
	if nfri5.Day() == 5 { pass = pass + 1 }
	if nfri5.Month() == 6 { pass = pass + 1 }

	// Mon -1 → previous Fri.
	var mon2 time.Time = time.Date(2026, 6, 1, 12, 0, 0, 0)
	var pmon time.Time = time.AddBusinessDays(mon2, -1)
	if pmon.Day() == 29 { pass = pass + 1 }
	if pmon.Month() == 5 { pass = pass + 1 }

	// Mon -5 → Mon week prior.
	var mon3 time.Time = time.Date(2026, 6, 1, 12, 0, 0, 0)
	var p5mon time.Time = time.AddBusinessDays(mon3, -5)
	if p5mon.Day() == 25 { pass = pass + 1 }
	if p5mon.Month() == 5 { pass = pass + 1 }

	// Time-of-day preserved.
	var t1 time.Time = time.Date(2026, 5, 28, 9, 30, 0, 0)
	var r1 time.Time = time.AddBusinessDays(t1, 1)
	if r1.Hour() == 9 { pass = pass + 1 }
	if r1.Minute() == 30 { pass = pass + 1 }

	// Result is always a weekday for n != 0.
	var sat time.Time = time.Date(2026, 5, 30, 12, 0, 0, 0)
	var nsat time.Time = time.AddBusinessDays(sat, 1)
	if time.IsWeekday(nsat) { pass = pass + 1 }

	// BusinessDaysBetween: Mon→Fri same week → 4.
	var a1 time.Time = time.Date(2026, 6, 1, 0, 0, 0, 0)
	var b1 time.Time = time.Date(2026, 6, 5, 0, 0, 0, 0)
	if time.BusinessDaysBetween(a1, b1) == 4 { pass = pass + 1 }

	// Same day → 0.
	var a2 time.Time = time.Date(2026, 6, 1, 0, 0, 0, 0)
	var b2 time.Time = time.Date(2026, 6, 1, 0, 0, 0, 0)
	if time.BusinessDaysBetween(a2, b2) == 0 { pass = pass + 1 }

	// Mon→next Mon = 5 weekdays in between (Tue, Wed, Thu, Fri, next Mon).
	var a3 time.Time = time.Date(2026, 6, 1, 0, 0, 0, 0)
	var b3 time.Time = time.Date(2026, 6, 8, 0, 0, 0, 0)
	if time.BusinessDaysBetween(a3, b3) == 5 { pass = pass + 1 }

	// Reverse direction → negative.
	var a4 time.Time = time.Date(2026, 6, 5, 0, 0, 0, 0)
	var b4 time.Time = time.Date(2026, 6, 1, 0, 0, 0, 0)
	if time.BusinessDaysBetween(a4, b4) == -4 { pass = pass + 1 }

	// SLA use case: ship within 3 business days from Fri.
	var orderFri time.Time = time.Date(2026, 5, 29, 14, 0, 0, 0)
	var shipBy time.Time = time.AddBusinessDays(orderFri, 3)
	// Fri+3 BD = next Wed (Mon, Tue, Wed).
	if shipBy.Day() == 3 { pass = pass + 1 }
	if shipBy.Month() == 6 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
