package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// EarliestOf — single.
	var solo []time.Time = new(1) []time.Time {}
	solo[0] = time.Date(2025, 6, 1, 0, 0, 0, 0)
	var e1 time.Time = time.EarliestOf(solo)
	if e1.Year() == 2025 { pass = pass + 1 }
	if e1.Month() == 6 { pass = pass + 1 }

	// LatestOf — single.
	var solo2 []time.Time = new(1) []time.Time {}
	solo2[0] = time.Date(2025, 6, 1, 0, 0, 0, 0)
	var l1 time.Time = time.LatestOf(solo2)
	if l1.Year() == 2025 { pass = pass + 1 }

	// EarliestOf — 4 times spanning years.
	var four []time.Time = new(4) []time.Time {}
	four[0] = time.Date(2024, 3, 15, 0, 0, 0, 0)
	four[1] = time.Date(2026, 1, 1, 0, 0, 0, 0)
	four[2] = time.Date(2020, 12, 31, 0, 0, 0, 0)
	four[3] = time.Date(2025, 7, 4, 0, 0, 0, 0)
	var e2 time.Time = time.EarliestOf(four)
	if e2.Year() == 2020 { pass = pass + 1 }
	if e2.Month() == 12 { pass = pass + 1 }
	if e2.Day() == 31 { pass = pass + 1 }

	// LatestOf — 4 times. Need fresh slice since `four` was moved.
	var four2 []time.Time = new(4) []time.Time {}
	four2[0] = time.Date(2024, 3, 15, 0, 0, 0, 0)
	four2[1] = time.Date(2026, 1, 1, 0, 0, 0, 0)
	four2[2] = time.Date(2020, 12, 31, 0, 0, 0, 0)
	four2[3] = time.Date(2025, 7, 4, 0, 0, 0, 0)
	var l2 time.Time = time.LatestOf(four2)
	if l2.Year() == 2026 { pass = pass + 1 }
	if l2.Month() == 1 { pass = pass + 1 }
	if l2.Day() == 1 { pass = pass + 1 }

	// Empty input → zero time.
	var empty []time.Time = new(0) []time.Time {}
	var e3 time.Time = time.EarliestOf(empty)
	if e3.UnixNano() == 0 { pass = pass + 1 }
	var empty2 []time.Time = new(0) []time.Time {}
	var l3 time.Time = time.LatestOf(empty2)
	if l3.UnixNano() == 0 { pass = pass + 1 }

	// All equal — both return the same.
	var same []time.Time = new(3) []time.Time {}
	same[0] = time.Date(2024, 1, 1, 0, 0, 0, 0)
	same[1] = time.Date(2024, 1, 1, 0, 0, 0, 0)
	same[2] = time.Date(2024, 1, 1, 0, 0, 0, 0)
	var e4 time.Time = time.EarliestOf(same)
	var same2 []time.Time = new(3) []time.Time {}
	same2[0] = time.Date(2024, 1, 1, 0, 0, 0, 0)
	same2[1] = time.Date(2024, 1, 1, 0, 0, 0, 0)
	same2[2] = time.Date(2024, 1, 1, 0, 0, 0, 0)
	var l4 time.Time = time.LatestOf(same2)
	if e4.Equal(l4) { pass = pass + 1 }

	// Use case: "most recent event" in a 5-entry log.
	var events []time.Time = new(5) []time.Time {}
	events[0] = time.Date(2026, 5, 28, 9, 0, 0, 0)
	events[1] = time.Date(2026, 5, 28, 11, 30, 0, 0)
	events[2] = time.Date(2026, 5, 28, 8, 45, 0, 0)
	events[3] = time.Date(2026, 5, 28, 14, 22, 0, 0)
	events[4] = time.Date(2026, 5, 28, 10, 15, 0, 0)
	var mostRecent time.Time = time.LatestOf(events)
	if mostRecent.Hour() == 14 { pass = pass + 1 }
	if mostRecent.Minute() == 22 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
