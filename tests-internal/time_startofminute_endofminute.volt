package main
import "log"
import "time"

// Positive test: (t Time).StartOfMinute + (t Time).EndOfMinute.

fun main() int {
	var pass int = 0

	// Mid-minute basic.
	var t1 time.Time = time.Date(2024, 6, 15, 14, 35, 27, 123456789)
	var sm time.Time = t1.StartOfMinute()
	if sm.Year() == 2024 { pass = pass + 1 }
	if sm.Month() == 6 { pass = pass + 1 }
	if sm.Day() == 15 { pass = pass + 1 }
	if sm.Hour() == 14 { pass = pass + 1 }
	if sm.Minute() == 35 { pass = pass + 1 }
	if sm.Second() == 0 { pass = pass + 1 }

	var em time.Time = t1.EndOfMinute()
	if em.Hour() == 14 { pass = pass + 1 }
	if em.Minute() == 35 { pass = pass + 1 }
	if em.Second() == 59 { pass = pass + 1 }

	// Minute boundary.
	var t2 time.Time = time.Date(2024, 6, 15, 10, 30, 0, 0)
	var sm2 time.Time = t2.StartOfMinute()
	if sm2.Minute() == 30 { pass = pass + 1 }
	if sm2.Second() == 0 { pass = pass + 1 }

	// EndOfMinute preserves the minute even when at second=0.
	var em2 time.Time = t2.EndOfMinute()
	if em2.Minute() == 30 { pass = pass + 1 }
	if em2.Second() == 59 { pass = pass + 1 }

	// Last minute of the hour.
	var t3 time.Time = time.Date(2024, 6, 15, 14, 59, 30, 0)
	var sm3 time.Time = t3.StartOfMinute()
	if sm3.Hour() == 14 { pass = pass + 1 }
	if sm3.Minute() == 59 { pass = pass + 1 }
	var em3 time.Time = t3.EndOfMinute()
	if em3.Hour() == 14 { pass = pass + 1 }
	if em3.Minute() == 59 { pass = pass + 1 }

	// Last minute of the day.
	var t4 time.Time = time.Date(2024, 6, 15, 23, 59, 30, 0)
	var em4 time.Time = t4.EndOfMinute()
	if em4.Day() == 15 { pass = pass + 1 }
	if em4.Hour() == 23 { pass = pass + 1 }
	if em4.Minute() == 59 { pass = pass + 1 }
	if em4.Second() == 59 { pass = pass + 1 }

	// IsBetween: t1 falls in [sm, em].
	if t1.IsBetween(sm, em) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
