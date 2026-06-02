package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// Happy path — typical date.
	var t1 time.Time = new time.Time {}
	var e1 error = nil
	t1, e1 = time.ParseDate("2024-06-15")
	if e1 == nil { pass = pass + 1 }
	if t1.Year() == 2024 { pass = pass + 1 }
	if t1.Month() == 6 { pass = pass + 1 }
	if t1.Day() == 15 { pass = pass + 1 }
	if t1.Hour() == 0 { pass = pass + 1 }
	if t1.Minute() == 0 { pass = pass + 1 }
	if t1.Second() == 0 { pass = pass + 1 }

	// Round-trip with DateString.
	var t2 time.Time = new time.Time {}
	var e2 error = nil
	t2, e2 = time.ParseDate("2026-05-27")
	if e2 == nil { pass = pass + 1 }
	if t2.DateString() == "2026-05-27" { pass = pass + 1 }

	// Year 1970-01-01 = epoch.
	var t3 time.Time = new time.Time {}
	var e3 error = nil
	t3, e3 = time.ParseDate("1970-01-01")
	if e3 == nil { pass = pass + 1 }
	if t3.UnixNano() == 0 { pass = pass + 1 }

	// Leap day.
	var t4 time.Time = new time.Time {}
	var e4 error = nil
	t4, e4 = time.ParseDate("2024-02-29")
	if e4 == nil { pass = pass + 1 }
	if t4.Day() == 29 { pass = pass + 1 }

	// Errors — reuse a single rolling Time slot. The ownership
	// checker requires every declared var be used; we dead-use the
	// rolled value with a noop `if .Year() < 0` after each call.
	var tx time.Time = new time.Time {}
	var ex error = nil

	tx, ex = time.ParseDate("2024-6-15")
	if ex != nil { pass = pass + 1 }
	if tx.Year() < 0 { ret 0 }

	tx, ex = time.ParseDate("")
	if ex != nil { pass = pass + 1 }
	if tx.Year() < 0 { ret 0 }

	tx, ex = time.ParseDate("2024-06-15T")
	if ex != nil { pass = pass + 1 }
	if tx.Year() < 0 { ret 0 }

	tx, ex = time.ParseDate("2024/06/15")
	if ex != nil { pass = pass + 1 }
	if tx.Year() < 0 { ret 0 }

	tx, ex = time.ParseDate("XXXX-06-15")
	if ex != nil { pass = pass + 1 }
	if tx.Year() < 0 { ret 0 }

	tx, ex = time.ParseDate("2024-13-01")
	if ex != nil { pass = pass + 1 }
	if tx.Year() < 0 { ret 0 }

	tx, ex = time.ParseDate("2024-06-32")
	if ex != nil { pass = pass + 1 }
	if tx.Year() < 0 { ret 0 }

	tx, ex = time.ParseDate("2024-00-15")
	if ex != nil { pass = pass + 1 }
	if tx.Year() < 0 { ret 0 }

	tx, ex = time.ParseDate("2024-06-00")
	if ex != nil { pass = pass + 1 }
	if tx.Year() < 0 { ret 0 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
