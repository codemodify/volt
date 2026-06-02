package main
import "log"
import "time"

// Positive test: (t Time).RoundToSecond + TruncateToSecond.

fun main() int {
	var pass int = 0

	// RoundToSecond — < 500ms rounds down.
	var t1 time.Time = time.Date(2024, 6, 15, 12, 30, 45, 100000000)   // 0.1s
	var r1 time.Time = t1.RoundToSecond()
	if r1.Second() == 45 { pass = pass + 1 }

	// RoundToSecond — > 500ms rounds up.
	var t2 time.Time = time.Date(2024, 6, 15, 12, 30, 45, 600000000)   // 0.6s
	var r2 time.Time = t2.RoundToSecond()
	if r2.Second() == 46 { pass = pass + 1 }

	// RoundToSecond — exactly 500ms rounds up.
	var t3 time.Time = time.Date(2024, 6, 15, 12, 30, 45, 500000000)
	var r3 time.Time = t3.RoundToSecond()
	if r3.Second() == 46 { pass = pass + 1 }

	// RoundToSecond — exact whole second stays.
	var exact time.Time = time.Date(2024, 6, 15, 12, 30, 45, 0)
	var rExact time.Time = exact.RoundToSecond()
	if rExact.Second() == 45 { pass = pass + 1 }

	// TruncateToSecond — strips sub-second precision.
	var t4 time.Time = time.Date(2024, 6, 15, 12, 30, 45, 999999999)
	var tr4 time.Time = t4.TruncateToSecond()
	if tr4.Second() == 45 { pass = pass + 1 }

	// TruncateToSecond — never rounds up.
	var t5 time.Time = time.Date(2024, 6, 15, 12, 30, 45, 999999999)
	var tr5 time.Time = t5.TruncateToSecond()
	if tr5.Minute() == 30 { pass = pass + 1 }
	if tr5.Second() == 45 { pass = pass + 1 }

	// TruncateToSecond — 0 nanos stays.
	var trExact time.Time = exact.TruncateToSecond()
	if trExact.Second() == 45 { pass = pass + 1 }

	// Trunc <= Round always.
	if t2.TruncateToSecond().Sub(t2.RoundToSecond()) <= 0 { pass = pass + 1 }

	// Trunc and Round agree when input is on the second.
	if exact.TruncateToSecond().Sub(exact.RoundToSecond()) == 0 { pass = pass + 1 }

	// Sub-second info lost in both.
	if t4.RoundToSecond().UnixNano() % 1000000000 == 0 { pass = pass + 1 }
	if t4.TruncateToSecond().UnixNano() % 1000000000 == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
