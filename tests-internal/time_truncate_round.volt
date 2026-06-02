package main
import "log"
import "time"

// Positive test: (t Time).Truncate / Round — bucket timestamps to
// the nearest multiple of d nanoseconds.

fun main() int {
	var pass int = 0

	// Truncate to the start of the hour.
	var t1 time.Time = time.Date(2024, 3, 15, 14, 47, 33, 0)
	var t1tr time.Time = t1.Truncate(time.Hour)
	if t1tr.Hour() == 14 { pass = pass + 1 }
	if t1tr.Minute() == 0 { pass = pass + 1 }
	if t1tr.Second() == 0 { pass = pass + 1 }

	// Truncate to the start of the day.
	var t2 time.Time = time.Date(2024, 3, 15, 14, 47, 33, 0)
	var t2tr time.Time = t2.Truncate(24 * time.Hour)
	if t2tr.Hour() == 0 { pass = pass + 1 }
	if t2tr.Day() == 15 { pass = pass + 1 }

	// Truncate to a minute.
	var t3 time.Time = time.Date(2024, 1, 1, 0, 30, 45, 999000000)
	var t3tr time.Time = t3.Truncate(time.Minute)
	if t3tr.Second() == 0 { pass = pass + 1 }

	// Truncate with d == 0 → unchanged.
	var t4 time.Time = time.Date(2024, 1, 1, 12, 0, 0, 0)
	var t4tr time.Time = t4.Truncate(0)
	if t4tr.Hour() == 12 { pass = pass + 1 }

	// Round: closer to the next hour → round up.
	var t5 time.Time = time.Date(2024, 1, 1, 14, 35, 0, 0)
	var t5r time.Time = t5.Round(time.Hour)
	if t5r.Hour() == 15 { pass = pass + 1 }

	// Round: closer to current hour → round down.
	var t6 time.Time = time.Date(2024, 1, 1, 14, 20, 0, 0)
	var t6r time.Time = t6.Round(time.Hour)
	if t6r.Hour() == 14 { pass = pass + 1 }

	// Round half: exactly half-way rounds away from zero.
	var t7 time.Time = time.Date(2024, 1, 1, 14, 30, 0, 0)
	var t7r time.Time = t7.Round(time.Hour)
	if t7r.Hour() == 15 { pass = pass + 1 }

	// Round to second.
	var t8 time.Time = time.Date(2024, 1, 1, 0, 0, 5, 700000000)
	var t8r time.Time = t8.Round(time.Second)
	if t8r.Second() == 6 { pass = pass + 1 }

	log.Println("pass=%d t1tr=%s t5r=%s", pass, t1tr.Format(), t5r.Format())
	if pass == 11 { ret 42 }
	ret 0
}
