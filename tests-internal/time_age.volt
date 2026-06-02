package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// Birth 1990-05-15, ref 2026-05-28 (already had birthday) → 36.
	var birth time.Time = time.Date(1990, 5, 15, 0, 0, 0, 0)
	var ref time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	if time.AgeInYears(birth, ref) == 36 { pass = pass + 1 }

	// Birth 1990-12-15, ref 2026-05-28 (not yet had birthday) → 35.
	var birth2 time.Time = time.Date(1990, 12, 15, 0, 0, 0, 0)
	var ref2 time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	if time.AgeInYears(birth2, ref2) == 35 { pass = pass + 1 }

	// Same year, before birthday → 0 (still age 0).
	var birth3 time.Time = time.Date(2026, 5, 15, 0, 0, 0, 0)
	var ref3 time.Time = time.Date(2026, 5, 14, 0, 0, 0, 0)
	if time.AgeInYears(birth3, ref3) == 0 { pass = pass + 1 }

	// On birthday → age increments.
	var birth4 time.Time = time.Date(2000, 5, 28, 0, 0, 0, 0)
	var ref4 time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	if time.AgeInYears(birth4, ref4) == 26 { pass = pass + 1 }

	// Day before birthday → still previous age.
	var birth5 time.Time = time.Date(2000, 5, 28, 0, 0, 0, 0)
	var ref5 time.Time = time.Date(2026, 5, 27, 0, 0, 0, 0)
	if time.AgeInYears(birth5, ref5) == 25 { pass = pass + 1 }

	// Same year same day → 0.
	var birth6 time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	var ref6 time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	if time.AgeInYears(birth6, ref6) == 0 { pass = pass + 1 }

	// Newborn (1 day old).
	var birth7 time.Time = time.Date(2026, 5, 27, 0, 0, 0, 0)
	var ref7 time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	if time.AgeInYears(birth7, ref7) == 0 { pass = pass + 1 }

	// Birth after ref → 0 (no negative ages).
	var birth8 time.Time = time.Date(2030, 1, 1, 0, 0, 0, 0)
	var ref8 time.Time = time.Date(2026, 1, 1, 0, 0, 0, 0)
	if time.AgeInYears(birth8, ref8) == 0 { pass = pass + 1 }

	// Leap-day birthday: Feb 29, 2000.
	var leapBirth time.Time = time.Date(2000, 2, 29, 0, 0, 0, 0)
	var ref9 time.Time = time.Date(2026, 2, 28, 0, 0, 0, 0)   // not yet had Feb 29 birthday (and 2026 isn't leap)
	if time.AgeInYears(leapBirth, ref9) == 25 { pass = pass + 1 }

	// Leap-day Feb 29 birthday, ref March 1 → had birthday.
	var leapBirth2 time.Time = time.Date(2000, 2, 29, 0, 0, 0, 0)
	var ref10 time.Time = time.Date(2026, 3, 1, 0, 0, 0, 0)
	if time.AgeInYears(leapBirth2, ref10) == 26 { pass = pass + 1 }

	// Centennial.
	var birth11 time.Time = time.Date(1926, 5, 28, 0, 0, 0, 0)
	var ref11 time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	if time.AgeInYears(birth11, ref11) == 100 { pass = pass + 1 }

	// One year diff exactly.
	var birth12 time.Time = time.Date(2025, 5, 28, 0, 0, 0, 0)
	var ref12 time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	if time.AgeInYears(birth12, ref12) == 1 { pass = pass + 1 }

	// Birth day-after-ref-day-in-same-month.
	var birth13 time.Time = time.Date(2000, 5, 30, 0, 0, 0, 0)
	var ref13 time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	if time.AgeInYears(birth13, ref13) == 25 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
