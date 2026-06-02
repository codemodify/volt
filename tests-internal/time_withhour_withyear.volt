package main
import "log"
import "time"

// Positive test: (t Time).WithHour + WithYear.

fun main() int {
	var pass int = 0

	// WithHour — keep date and minute/second.
	var t1 time.Time = time.Date(2024, 6, 15, 9, 30, 45, 0)
	var nine time.Time = t1.WithHour(9)
	if nine.Hour() == 9 { pass = pass + 1 }
	if nine.Minute() == 30 { pass = pass + 1 }
	if nine.Second() == 45 { pass = pass + 1 }
	if nine.Day() == 15 { pass = pass + 1 }

	// WithHour — swap to different hour.
	var midnight time.Time = t1.WithHour(0)
	if midnight.Hour() == 0 { pass = pass + 1 }
	if midnight.Minute() == 30 { pass = pass + 1 }
	if midnight.Day() == 15 { pass = pass + 1 }

	// WithHour — swap to 23.
	var late time.Time = t1.WithHour(23)
	if late.Hour() == 23 { pass = pass + 1 }
	if late.Minute() == 30 { pass = pass + 1 }

	// WithYear — keep month, day, time.
	var y2025 time.Time = t1.WithYear(2025)
	if y2025.Year() == 2025 { pass = pass + 1 }
	if y2025.Month() == 6 { pass = pass + 1 }
	if y2025.Day() == 15 { pass = pass + 1 }
	if y2025.Hour() == 9 { pass = pass + 1 }
	if y2025.Minute() == 30 { pass = pass + 1 }
	if y2025.Second() == 45 { pass = pass + 1 }

	// WithYear — go back to 2020.
	var y2020 time.Time = t1.WithYear(2020)
	if y2020.Year() == 2020 { pass = pass + 1 }
	if y2020.Month() == 6 { pass = pass + 1 }
	if y2020.Day() == 15 { pass = pass + 1 }

	// WithYear with leap-day Feb 29 → non-leap year (overflows to Mar 1).
	var leap time.Time = time.Date(2024, 2, 29, 0, 0, 0, 0)
	var nonLeap time.Time = leap.WithYear(2025)
	if nonLeap.Year() == 2025 { pass = pass + 1 }
	if nonLeap.Month() == 3 { pass = pass + 1 }
	if nonLeap.Day() == 1 { pass = pass + 1 }

	// Composition: WithHour then WithYear.
	var combo time.Time = t1.WithHour(20).WithYear(2030)
	if combo.Year() == 2030 { pass = pass + 1 }
	if combo.Hour() == 20 { pass = pass + 1 }
	if combo.Minute() == 30 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
