package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// Midnight is AM.
	var midnight time.Time = time.Date(2024, 6, 15, 0, 0, 0, 0)
	if midnight.IsAM() { pass = pass + 1 }
	if !midnight.IsPM() { pass = pass + 1 }

	// 11:59:59 AM.
	var lateAM time.Time = time.Date(2024, 6, 15, 11, 59, 59, 0)
	if lateAM.IsAM() { pass = pass + 1 }
	if !lateAM.IsPM() { pass = pass + 1 }

	// Noon is PM (boundary).
	var noon time.Time = time.Date(2024, 6, 15, 12, 0, 0, 0)
	if !noon.IsAM() { pass = pass + 1 }
	if noon.IsPM() { pass = pass + 1 }

	// 1 PM.
	var pm1 time.Time = time.Date(2024, 6, 15, 13, 0, 0, 0)
	if !pm1.IsAM() { pass = pass + 1 }
	if pm1.IsPM() { pass = pass + 1 }

	// 11:59:59 PM.
	var latePM time.Time = time.Date(2024, 6, 15, 23, 59, 59, 0)
	if !latePM.IsAM() { pass = pass + 1 }
	if latePM.IsPM() { pass = pass + 1 }

	// 6 AM and 6 PM.
	var am6 time.Time = time.Date(2024, 6, 15, 6, 0, 0, 0)
	if am6.IsAM() { pass = pass + 1 }
	if !am6.IsPM() { pass = pass + 1 }
	var pm6 time.Time = time.Date(2024, 6, 15, 18, 0, 0, 0)
	if !pm6.IsAM() { pass = pass + 1 }
	if pm6.IsPM() { pass = pass + 1 }

	// AM XOR PM invariant: every t is in exactly one half.
	var allValid bool = true
	for h := 0; h < 24; h++ {
		var t time.Time = time.Date(2024, 6, 15, h, 0, 0, 0)
		if t.IsAM() == t.IsPM() { allValid = false }
	}
	if allValid { pass = pass + 1 }

	// Consistent with Meridiem().
	if midnight.Meridiem() == "AM" { pass = pass + 1 }
	if noon.Meridiem() == "PM" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
