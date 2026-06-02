package main
import "log"
import "strings"
import "time"

// Positive test: strings.SplitMap + (t Time).IsLastDayOfMonth.

fun upper(s string) string { ret strings.ToUpper(s) }
fun trim(s string) string { ret strings.TrimSpace(s) }

fun main() int {
	var pass int = 0

	// SplitMap — upper each piece.
	var r []string = strings.SplitMap("a,b,c", ",", upper)
	if len(r) == 3 { pass = pass + 1 }
	if r[0] == "A" { pass = pass + 1 }
	if r[1] == "B" { pass = pass + 1 }
	if r[2] == "C" { pass = pass + 1 }

	// SplitMap — trim each piece.
	var t []string = strings.SplitMap("  foo  ,  bar , baz  ", ",", trim)
	if t[0] == "foo" { pass = pass + 1 }
	if t[1] == "bar" { pass = pass + 1 }
	if t[2] == "baz" { pass = pass + 1 }

	// SplitMap — single piece (no separator).
	var s1 []string = strings.SplitMap("hello", ",", upper)
	if len(s1) == 1 { pass = pass + 1 }
	if s1[0] == "HELLO" { pass = pass + 1 }

	// SplitMap — empty input.
	var s2 []string = strings.SplitMap("", ",", upper)
	if len(s2) == 1 { pass = pass + 1 }   // Split returns [""]
	if s2[0] == "" { pass = pass + 1 }

	// IsLastDayOfMonth — March 31.
	var mar31 time.Time = time.Date(2024, 3, 31, 0, 0, 0, 0)
	if mar31.IsLastDayOfMonth() { pass = pass + 1 }

	// February — leap year (29).
	var feb29 time.Time = time.Date(2024, 2, 29, 0, 0, 0, 0)
	if feb29.IsLastDayOfMonth() { pass = pass + 1 }

	// February non-leap (28).
	var feb28 time.Time = time.Date(2023, 2, 28, 0, 0, 0, 0)
	if feb28.IsLastDayOfMonth() { pass = pass + 1 }

	// February 28 in leap year is NOT last day.
	var feb28leap time.Time = time.Date(2024, 2, 28, 0, 0, 0, 0)
	if !feb28leap.IsLastDayOfMonth() { pass = pass + 1 }

	// April 30 — last day.
	var apr30 time.Time = time.Date(2024, 4, 30, 0, 0, 0, 0)
	if apr30.IsLastDayOfMonth() { pass = pass + 1 }

	// April 30 isn't last for 31-day month.
	var mar30 time.Time = time.Date(2024, 3, 30, 0, 0, 0, 0)
	if !mar30.IsLastDayOfMonth() { pass = pass + 1 }

	// December 31.
	var dec31 time.Time = time.Date(2024, 12, 31, 0, 0, 0, 0)
	if dec31.IsLastDayOfMonth() { pass = pass + 1 }

	// Mid-month not last.
	var mid time.Time = time.Date(2024, 6, 15, 0, 0, 0, 0)
	if !mid.IsLastDayOfMonth() { pass = pass + 1 }

	// Day 1 not last.
	var first time.Time = time.Date(2024, 6, 1, 0, 0, 0, 0)
	if !first.IsLastDayOfMonth() { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
