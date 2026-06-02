package main
import "log"
import "time"

// Positive test: (t Time).IsSameDay + IsSameMonth + IsSameYear.

fun main() int {
	var pass int = 0

	// Same day, different times.
	var morning time.Time = time.Date(2024, 3, 15, 8, 0, 0, 0)
	var evening time.Time = time.Date(2024, 3, 15, 22, 30, 0, 0)
	if morning.IsSameDay(evening) { pass = pass + 1 }
	if morning.IsSameMonth(evening) { pass = pass + 1 }
	if morning.IsSameYear(evening) { pass = pass + 1 }

	// Next day, same month.
	var nextDay time.Time = time.Date(2024, 3, 16, 0, 0, 0, 0)
	if !morning.IsSameDay(nextDay) { pass = pass + 1 }
	if morning.IsSameMonth(nextDay) { pass = pass + 1 }
	if morning.IsSameYear(nextDay) { pass = pass + 1 }

	// Next month.
	var nextMonth time.Time = time.Date(2024, 4, 15, 0, 0, 0, 0)
	if !morning.IsSameDay(nextMonth) { pass = pass + 1 }
	if !morning.IsSameMonth(nextMonth) { pass = pass + 1 }
	if morning.IsSameYear(nextMonth) { pass = pass + 1 }

	// Next year, same month/day.
	var nextYear time.Time = time.Date(2025, 3, 15, 0, 0, 0, 0)
	if !morning.IsSameDay(nextYear) { pass = pass + 1 }
	if !morning.IsSameMonth(nextYear) { pass = pass + 1 }
	if !morning.IsSameYear(nextYear) { pass = pass + 1 }

	// Self-comparison.
	if morning.IsSameDay(morning) { pass = pass + 1 }
	if morning.IsSameMonth(morning) { pass = pass + 1 }
	if morning.IsSameYear(morning) { pass = pass + 1 }

	// Midnight boundary — second before midnight is same day, midnight itself is next.
	var lateAt1ns time.Time = time.Date(2024, 3, 15, 23, 59, 59, 999999999)
	var midnight time.Time = time.Date(2024, 3, 16, 0, 0, 0, 0)
	if morning.IsSameDay(lateAt1ns) { pass = pass + 1 }
	if !morning.IsSameDay(midnight) { pass = pass + 1 }

	// Pre-epoch + post-epoch year cross.
	var pre time.Time = time.Date(1969, 12, 31, 23, 0, 0, 0)
	var post time.Time = time.Date(1970, 1, 1, 0, 0, 0, 0)
	if !pre.IsSameYear(post) { pass = pass + 1 }
	if !pre.IsSameMonth(post) { pass = pass + 1 }
	if !pre.IsSameDay(post) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
