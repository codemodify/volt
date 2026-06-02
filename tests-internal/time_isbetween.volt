package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	var t1 time.Time = time.Date(2024, 6, 15, 12, 0, 0, 0)
	var lo time.Time = time.Date(2024, 6, 1, 0, 0, 0, 0)
	var hi time.Time = time.Date(2024, 6, 30, 23, 59, 59, 0)

	// In range.
	if time.TimeIsBetween(t1, lo, hi) { pass = pass + 1 }

	// Before range.
	var early time.Time = time.Date(2024, 5, 31, 23, 59, 59, 0)
	if !time.TimeIsBetween(early, lo, hi) { pass = pass + 1 }

	// After range.
	var late time.Time = time.Date(2024, 7, 1, 0, 0, 0, 0)
	if !time.TimeIsBetween(late, lo, hi) { pass = pass + 1 }

	// Boundary inclusive on lo.
	var atLo time.Time = time.Date(2024, 6, 1, 0, 0, 0, 0)
	if time.TimeIsBetween(atLo, lo, hi) { pass = pass + 1 }

	// Boundary inclusive on hi.
	var atHi time.Time = time.Date(2024, 6, 30, 23, 59, 59, 0)
	if time.TimeIsBetween(atHi, lo, hi) { pass = pass + 1 }

	// Degenerate range (lo > hi) → false.
	var t2 time.Time = time.Date(2024, 6, 15, 12, 0, 0, 0)
	var lo2 time.Time = time.Date(2024, 12, 1, 0, 0, 0, 0)
	var hi2 time.Time = time.Date(2024, 1, 1, 0, 0, 0, 0)
	if !time.TimeIsBetween(t2, lo2, hi2) { pass = pass + 1 }

	// Single-instant range (lo == hi).
	var t3 time.Time = time.Date(2024, 6, 15, 12, 0, 0, 0)
	var pt time.Time = time.Date(2024, 6, 15, 12, 0, 0, 0)
	if time.TimeIsBetween(t3, pt, pt) { pass = pass + 1 }

	// Just outside single-instant range.
	var off time.Time = time.Date(2024, 6, 15, 12, 0, 0, 1)
	var ptl time.Time = time.Date(2024, 6, 15, 12, 0, 0, 0)
	var pth time.Time = time.Date(2024, 6, 15, 12, 0, 0, 0)
	if !time.TimeIsBetween(off, ptl, pth) { pass = pass + 1 }

	// Use case: business-hours window.
	var event time.Time = time.Date(2026, 5, 28, 14, 30, 0, 0)
	var biz_open time.Time = time.Date(2026, 5, 28, 9, 0, 0, 0)
	var biz_close time.Time = time.Date(2026, 5, 28, 17, 0, 0, 0)
	if time.TimeIsBetween(event, biz_open, biz_close) { pass = pass + 1 }

	// Outside business hours.
	var ev2 time.Time = time.Date(2026, 5, 28, 22, 0, 0, 0)
	var bo2 time.Time = time.Date(2026, 5, 28, 9, 0, 0, 0)
	var bc2 time.Time = time.Date(2026, 5, 28, 17, 0, 0, 0)
	if !time.TimeIsBetween(ev2, bo2, bc2) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 10 { ret 42 }
	ret 0
}
