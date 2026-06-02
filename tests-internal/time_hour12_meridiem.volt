package main
import "log"
import "time"

// Positive test: (t Time).Hour12 + (t Time).Meridiem.

fun main() int {
	var pass int = 0

	// Hour12 — midnight = 12.
	var midnight time.Time = time.Date(2024, 6, 15, 0, 0, 0, 0)
	if midnight.Hour12() == 12 { pass = pass + 1 }
	if midnight.Meridiem() == "AM" { pass = pass + 1 }

	// Hour12 — 1 AM.
	var am1 time.Time = time.Date(2024, 6, 15, 1, 0, 0, 0)
	if am1.Hour12() == 1 { pass = pass + 1 }
	if am1.Meridiem() == "AM" { pass = pass + 1 }

	// Hour12 — 11 AM.
	var am11 time.Time = time.Date(2024, 6, 15, 11, 0, 0, 0)
	if am11.Hour12() == 11 { pass = pass + 1 }
	if am11.Meridiem() == "AM" { pass = pass + 1 }

	// Hour12 — noon = 12 PM.
	var noon time.Time = time.Date(2024, 6, 15, 12, 0, 0, 0)
	if noon.Hour12() == 12 { pass = pass + 1 }
	if noon.Meridiem() == "PM" { pass = pass + 1 }

	// Hour12 — 1 PM.
	var pm1 time.Time = time.Date(2024, 6, 15, 13, 0, 0, 0)
	if pm1.Hour12() == 1 { pass = pass + 1 }
	if pm1.Meridiem() == "PM" { pass = pass + 1 }

	// Hour12 — 11 PM.
	var pm11 time.Time = time.Date(2024, 6, 15, 23, 0, 0, 0)
	if pm11.Hour12() == 11 { pass = pass + 1 }
	if pm11.Meridiem() == "PM" { pass = pass + 1 }

	// Hour12 — 6 AM.
	var am6 time.Time = time.Date(2024, 6, 15, 6, 30, 0, 0)
	if am6.Hour12() == 6 { pass = pass + 1 }
	if am6.Meridiem() == "AM" { pass = pass + 1 }

	// Hour12 — 6 PM.
	var pm6 time.Time = time.Date(2024, 6, 15, 18, 45, 0, 0)
	if pm6.Hour12() == 6 { pass = pass + 1 }
	if pm6.Meridiem() == "PM" { pass = pass + 1 }

	// Hour12 + Meridiem invariant: hour 24h = ((Hour12 mod 12) + (PM ? 12 : 0)).
	// 23:00 → 11 PM → 11 + 12 = 23.
	if pm11.Hour12() + 12 == 23 { pass = pass + 1 }

	// All Hour12 values are in [1, 12].
	var allValid bool = true
	for h := 0; h < 24; h++ {
		var t time.Time = time.Date(2024, 6, 15, h, 0, 0, 0)
		var h12 int = t.Hour12()
		if h12 < 1 { allValid = false }
		if h12 > 12 { allValid = false }
	}
	if allValid { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
