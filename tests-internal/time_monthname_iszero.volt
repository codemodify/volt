package main
import "log"
import "time"

// Positive test: time.MonthName + (t Time).IsZero.

fun main() int {
	var pass int = 0

	// MonthName.
	if time.MonthName(1) == "January" { pass = pass + 1 }
	if time.MonthName(2) == "February" { pass = pass + 1 }
	if time.MonthName(3) == "March" { pass = pass + 1 }
	if time.MonthName(6) == "June" { pass = pass + 1 }
	if time.MonthName(12) == "December" { pass = pass + 1 }

	// Out-of-range → "".
	if time.MonthName(0) == "" { pass = pass + 1 }
	if time.MonthName(13) == "" { pass = pass + 1 }
	if time.MonthName(-1) == "" { pass = pass + 1 }

	// IsZero.
	var t1 time.Time = time.FromNano(0)
	if t1.IsZero() { pass = pass + 1 }

	// Real time → not zero.
	var t2 time.Time = time.Date(2024, 3, 15, 0, 0, 0, 0)
	if !t2.IsZero() { pass = pass + 1 }

	// Pre-epoch → not zero.
	var t3 time.Time = time.FromNano(-1)
	if !t3.IsZero() { pass = pass + 1 }

	// Combine: print "March 15, 2024" style.
	var t4 time.Time = time.Date(2024, 3, 15, 0, 0, 0, 0)
	var name string = time.MonthName(t4.Month())
	if name == "March" { pass = pass + 1 }

	log.Println("pass=%d name=%s", pass, name)
	if pass == 12 { ret 42 }
	ret 0
}
