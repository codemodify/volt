package main
import "log"
import "time"
import "strings"

// Positive test: (t Time).DayOfWeekISO + strings.RepeatRune.

fun main() int {
	var pass int = 0

	// Walk a known week starting Sunday 2024-05-26 — ISO numbering 7,1,2,3,4,5,6.
	if time.Date(2024, 5, 26, 0, 0, 0, 0).DayOfWeekISO() == 7 { pass = pass + 1 }   // Sun
	if time.Date(2024, 5, 27, 0, 0, 0, 0).DayOfWeekISO() == 1 { pass = pass + 1 }   // Mon
	if time.Date(2024, 5, 28, 0, 0, 0, 0).DayOfWeekISO() == 2 { pass = pass + 1 }   // Tue
	if time.Date(2024, 5, 29, 0, 0, 0, 0).DayOfWeekISO() == 3 { pass = pass + 1 }   // Wed
	if time.Date(2024, 5, 30, 0, 0, 0, 0).DayOfWeekISO() == 4 { pass = pass + 1 }   // Thu
	if time.Date(2024, 5, 31, 0, 0, 0, 0).DayOfWeekISO() == 5 { pass = pass + 1 }   // Fri
	if time.Date(2024, 6, 1, 0, 0, 0, 0).DayOfWeekISO() == 6 { pass = pass + 1 }    // Sat

	// Epoch (Thursday).
	if time.FromNano(0).DayOfWeekISO() == 4 { pass = pass + 1 }

	// RepeatRune ASCII.
	if strings.RepeatRune("a", 5) == "aaaaa" { pass = pass + 1 }
	if strings.RepeatRune("-", 3) == "---" { pass = pass + 1 }
	if strings.RepeatRune("X", 1) == "X" { pass = pass + 1 }

	// Multi-byte rune.
	if strings.RepeatRune("\xC3\xA9", 3) == "\xC3\xA9\xC3\xA9\xC3\xA9" { pass = pass + 1 }
	// 3-byte rune.
	if strings.RepeatRune("\xE4\xB8\x96", 2) == "\xE4\xB8\x96\xE4\xB8\x96" { pass = pass + 1 }

	// Edge: n <= 0.
	if strings.RepeatRune("X", 0) == "" { pass = pass + 1 }
	if strings.RepeatRune("X", -3) == "" { pass = pass + 1 }

	// Edge: empty r.
	if strings.RepeatRune("", 5) == "" { pass = pass + 1 }

	// Multi-char string is fine too (we don't enforce single-rune).
	if strings.RepeatRune("ab", 3) == "ababab" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
