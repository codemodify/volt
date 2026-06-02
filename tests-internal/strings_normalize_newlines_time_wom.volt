package main
import "log"
import "strings"
import "time"

// Positive test: strings.NormalizeNewlines + (t Time).WeekOfMonth.

fun main() int {
	var pass int = 0

	// NormalizeNewlines — basic.
	if strings.NormalizeNewlines("hello\r\nworld") == "hello\nworld" { pass = pass + 1 }
	if strings.NormalizeNewlines("hello\rworld") == "hello\nworld" { pass = pass + 1 }
	if strings.NormalizeNewlines("hello\nworld") == "hello\nworld" { pass = pass + 1 }
	if strings.NormalizeNewlines("") == "" { pass = pass + 1 }

	// Multiple line endings.
	if strings.NormalizeNewlines("a\r\nb\nc\r\nd") == "a\nb\nc\nd" { pass = pass + 1 }
	// Mixed CR and CRLF.
	if strings.NormalizeNewlines("a\rb\r\nc") == "a\nb\nc" { pass = pass + 1 }
	// Trailing CR.
	if strings.NormalizeNewlines("foo\r") == "foo\n" { pass = pass + 1 }
	// Trailing CRLF.
	if strings.NormalizeNewlines("foo\r\n") == "foo\n" { pass = pass + 1 }
	// Lone CR (not followed by LF).
	if strings.NormalizeNewlines("\r") == "\n" { pass = pass + 1 }

	// WeekOfMonth — 2024-05 starts on a Wednesday.
	// Day 1-4 = week 1; day 5-11 = week 2; etc.
	if time.Date(2024, 5, 1, 0, 0, 0, 0).WeekOfMonth() == 1 { pass = pass + 1 }
	if time.Date(2024, 5, 4, 0, 0, 0, 0).WeekOfMonth() == 1 { pass = pass + 1 }   // Sat
	if time.Date(2024, 5, 5, 0, 0, 0, 0).WeekOfMonth() == 2 { pass = pass + 1 }   // Sun starts wk 2
	if time.Date(2024, 5, 11, 0, 0, 0, 0).WeekOfMonth() == 2 { pass = pass + 1 }   // Sat
	if time.Date(2024, 5, 12, 0, 0, 0, 0).WeekOfMonth() == 3 { pass = pass + 1 }
	if time.Date(2024, 5, 31, 0, 0, 0, 0).WeekOfMonth() == 5 { pass = pass + 1 }   // Fri of week 5

	// 2024-09 starts on Sunday — day 1 is wk 1.
	if time.Date(2024, 9, 1, 0, 0, 0, 0).WeekOfMonth() == 1 { pass = pass + 1 }
	if time.Date(2024, 9, 7, 0, 0, 0, 0).WeekOfMonth() == 1 { pass = pass + 1 }
	if time.Date(2024, 9, 8, 0, 0, 0, 0).WeekOfMonth() == 2 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
