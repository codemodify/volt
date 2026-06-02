package main
import "log"
import "time"

// Positive test: (t Time).WeeksBetween + (t Time).MonthsBetween.

fun main() int {
	var pass int = 0

	// WeeksBetween — exact week multiples.
	var t1 time.Time = time.Date(2024, 1, 1, 0, 0, 0, 0)
	var t2 time.Time = time.Date(2024, 1, 8, 0, 0, 0, 0)   // 7 days later
	if t2.WeeksBetween(t1) == 1 { pass = pass + 1 }

	var t3 time.Time = time.Date(2024, 4, 1, 0, 0, 0, 0)   // 91 days later → 13 weeks
	if t3.WeeksBetween(t1) == 13 { pass = pass + 1 }

	// WeeksBetween — partial weeks floor toward zero.
	var t4 time.Time = time.Date(2024, 1, 6, 0, 0, 0, 0)   // 5 days → 0 weeks
	if t4.WeeksBetween(t1) == 0 { pass = pass + 1 }

	var t5 time.Time = time.Date(2024, 1, 14, 0, 0, 0, 0)  // 13 days → 1 week
	if t5.WeeksBetween(t1) == 1 { pass = pass + 1 }

	// WeeksBetween — negative when u is later.
	if t1.WeeksBetween(t2) == -1 { pass = pass + 1 }

	// WeeksBetween — same day = 0.
	if t1.WeeksBetween(t1) == 0 { pass = pass + 1 }

	// MonthsBetween — exact month boundaries.
	var jan time.Time = time.Date(2024, 1, 15, 0, 0, 0, 0)
	var feb time.Time = time.Date(2024, 2, 15, 0, 0, 0, 0)
	if feb.MonthsBetween(jan) == 1 { pass = pass + 1 }

	var mar time.Time = time.Date(2024, 3, 15, 0, 0, 0, 0)
	if mar.MonthsBetween(jan) == 2 { pass = pass + 1 }

	// MonthsBetween — same month, different day = 0.
	var jan20 time.Time = time.Date(2024, 1, 20, 0, 0, 0, 0)
	if jan20.MonthsBetween(jan) == 0 { pass = pass + 1 }

	// MonthsBetween — partial month not counted.
	// 2024-01-15 → 2024-02-14 = 30 days, but only 0 full months (day-of-month earlier).
	var feb14 time.Time = time.Date(2024, 2, 14, 0, 0, 0, 0)
	if feb14.MonthsBetween(jan) == 0 { pass = pass + 1 }

	// MonthsBetween — exactly one month + 1 day.
	var feb16 time.Time = time.Date(2024, 2, 16, 0, 0, 0, 0)
	if feb16.MonthsBetween(jan) == 1 { pass = pass + 1 }

	// MonthsBetween — across year boundary.
	var dec time.Time = time.Date(2023, 12, 15, 0, 0, 0, 0)
	if jan.MonthsBetween(dec) == 1 { pass = pass + 1 }

	var jul2025 time.Time = time.Date(2025, 7, 15, 0, 0, 0, 0)
	if jul2025.MonthsBetween(jan) == 18 { pass = pass + 1 }

	// MonthsBetween — negative when u is later.
	if jan.MonthsBetween(feb) == -1 { pass = pass + 1 }

	// MonthsBetween — same instant = 0.
	if jan.MonthsBetween(jan) == 0 { pass = pass + 1 }

	// MonthsBetween — symmetric: A→B == -(B→A) when day-of-month aligns.
	if feb.MonthsBetween(jan) == -(jan.MonthsBetween(feb)) { pass = pass + 1 }

	// 12 months across full year.
	var jan2025 time.Time = time.Date(2025, 1, 15, 0, 0, 0, 0)
	if jan2025.MonthsBetween(jan) == 12 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
