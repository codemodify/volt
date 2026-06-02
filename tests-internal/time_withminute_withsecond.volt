package main
import "log"
import "time"

// Positive test: (t Time).WithMinute + WithSecond.

fun main() int {
	var pass int = 0

	var t1 time.Time = time.Date(2024, 6, 15, 9, 30, 45, 0)

	// WithMinute — basic.
	var m1 time.Time = t1.WithMinute(0)
	if m1.Minute() == 0 { pass = pass + 1 }
	if m1.Hour() == 9 { pass = pass + 1 }
	if m1.Second() == 45 { pass = pass + 1 }
	if m1.Day() == 15 { pass = pass + 1 }

	// WithMinute — swap to 59.
	var m59 time.Time = t1.WithMinute(59)
	if m59.Minute() == 59 { pass = pass + 1 }
	if m59.Hour() == 9 { pass = pass + 1 }

	// WithMinute — fixed-point.
	var sameMinute time.Time = t1.WithMinute(30)
	if sameMinute.Minute() == 30 { pass = pass + 1 }
	if sameMinute.Sub(t1) == 0 { pass = pass + 1 }

	// WithSecond — basic.
	var s1 time.Time = t1.WithSecond(0)
	if s1.Second() == 0 { pass = pass + 1 }
	if s1.Minute() == 30 { pass = pass + 1 }
	if s1.Hour() == 9 { pass = pass + 1 }

	// WithSecond — to 59.
	var s59 time.Time = t1.WithSecond(59)
	if s59.Second() == 59 { pass = pass + 1 }
	if s59.Minute() == 30 { pass = pass + 1 }

	// WithSecond — fixed-point.
	var sameSec time.Time = t1.WithSecond(45)
	if sameSec.Second() == 45 { pass = pass + 1 }
	if sameSec.Sub(t1) == 0 { pass = pass + 1 }

	// Method chaining: WithMinute then WithSecond.
	var chain time.Time = t1.WithMinute(0).WithSecond(0)
	if chain.Minute() == 0 { pass = pass + 1 }
	if chain.Second() == 0 { pass = pass + 1 }
	if chain.Hour() == 9 { pass = pass + 1 }

	// Combine with existing With* family.
	var anchored time.Time = t1.WithHour(0).WithMinute(0).WithSecond(0)
	if anchored.Hour() == 0 { pass = pass + 1 }
	if anchored.Minute() == 0 { pass = pass + 1 }
	if anchored.Second() == 0 { pass = pass + 1 }
	if anchored.Day() == 15 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
