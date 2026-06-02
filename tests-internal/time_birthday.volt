package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// IsBirthday: matching month+day.
	var birth time.Time = time.Date(1990, 5, 28, 0, 0, 0, 0)
	var ref time.Time = time.Date(2026, 5, 28, 12, 30, 0, 0)
	if time.IsBirthday(birth, ref) { pass = pass + 1 }

	// Different day.
	var birth2 time.Time = time.Date(1990, 5, 28, 0, 0, 0, 0)
	var ref2 time.Time = time.Date(2026, 5, 27, 0, 0, 0, 0)
	if !time.IsBirthday(birth2, ref2) { pass = pass + 1 }

	// Different month.
	var birth3 time.Time = time.Date(1990, 5, 28, 0, 0, 0, 0)
	var ref3 time.Time = time.Date(2026, 6, 28, 0, 0, 0, 0)
	if !time.IsBirthday(birth3, ref3) { pass = pass + 1 }

	// Year ignored.
	var birth4 time.Time = time.Date(1990, 5, 28, 0, 0, 0, 0)
	var ref4 time.Time = time.Date(1991, 5, 28, 0, 0, 0, 0)
	if time.IsBirthday(birth4, ref4) { pass = pass + 1 }

	// Time-of-day ignored.
	var birth5 time.Time = time.Date(1990, 5, 28, 23, 59, 0, 0)
	var ref5 time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	if time.IsBirthday(birth5, ref5) { pass = pass + 1 }

	// Leap-day birthday: Feb 29 matches only on Feb 29.
	var leap time.Time = time.Date(2000, 2, 29, 0, 0, 0, 0)
	var ref6 time.Time = time.Date(2024, 2, 29, 0, 0, 0, 0)
	if time.IsBirthday(leap, ref6) { pass = pass + 1 }
	var leap2 time.Time = time.Date(2000, 2, 29, 0, 0, 0, 0)
	var ref7 time.Time = time.Date(2026, 2, 28, 0, 0, 0, 0)
	if !time.IsBirthday(leap2, ref7) { pass = pass + 1 }
	var leap3 time.Time = time.Date(2000, 2, 29, 0, 0, 0, 0)
	var ref8 time.Time = time.Date(2026, 3, 1, 0, 0, 0, 0)
	if !time.IsBirthday(leap3, ref8) { pass = pass + 1 }

	// DaysUntilBirthday: on the day → 0.
	var birth9 time.Time = time.Date(1990, 5, 28, 0, 0, 0, 0)
	var ref9 time.Time = time.Date(2026, 5, 28, 12, 0, 0, 0)
	if time.DaysUntilBirthday(birth9, ref9) == 0 { pass = pass + 1 }

	// Day before.
	var birth10 time.Time = time.Date(1990, 5, 28, 0, 0, 0, 0)
	var ref10 time.Time = time.Date(2026, 5, 27, 0, 0, 0, 0)
	if time.DaysUntilBirthday(birth10, ref10) == 1 { pass = pass + 1 }

	// 7 days before.
	var birth11 time.Time = time.Date(1990, 5, 28, 0, 0, 0, 0)
	var ref11 time.Time = time.Date(2026, 5, 21, 0, 0, 0, 0)
	if time.DaysUntilBirthday(birth11, ref11) == 7 { pass = pass + 1 }

	// Day after → wraps to next year.
	// 1990-05-28 birth, ref 2026-05-29 → next is 2027-05-28 → 364 days (2027 non-leap).
	var birth12 time.Time = time.Date(1990, 5, 28, 0, 0, 0, 0)
	var ref12 time.Time = time.Date(2026, 5, 29, 0, 0, 0, 0)
	if time.DaysUntilBirthday(birth12, ref12) == 364 { pass = pass + 1 }

	// New year approach: Dec 25 birthday, ref Dec 24 → 1 day.
	var xmas time.Time = time.Date(1990, 12, 25, 0, 0, 0, 0)
	var ref13 time.Time = time.Date(2026, 12, 24, 0, 0, 0, 0)
	if time.DaysUntilBirthday(xmas, ref13) == 1 { pass = pass + 1 }

	// Feb 29 birthday in non-leap year → rolls to Mar 1, so:
	// ref Feb 28 2026, next "birthday" is Mar 1 2026 = 1 day away.
	var leap4 time.Time = time.Date(2000, 2, 29, 0, 0, 0, 0)
	var ref14 time.Time = time.Date(2026, 2, 28, 0, 0, 0, 0)
	if time.DaysUntilBirthday(leap4, ref14) == 1 { pass = pass + 1 }

	// Use case: render "happy birthday" or "X days until your birthday".
	var birth15 time.Time = time.Date(1990, 5, 28, 0, 0, 0, 0)
	var ref15 time.Time = time.Date(2026, 5, 28, 0, 0, 0, 0)
	if time.IsBirthday(birth15, ref15) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
