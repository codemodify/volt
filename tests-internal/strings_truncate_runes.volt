package main
import "log"
import "strings"

// Positive test: strings.Truncate + FirstRune + LastRune.

fun main() int {
	var pass int = 0

	// Truncate — fits.
	if strings.Truncate("hi", 10, "...") == "hi" { pass = pass + 1 }
	// Exact length — no truncation.
	if strings.Truncate("hello", 5, "...") == "hello" { pass = pass + 1 }
	// Truncate with ellipsis.
	if strings.Truncate("hello world", 8, "...") == "hello..." { pass = pass + 1 }
	// Truncate without ellipsis.
	if strings.Truncate("hello world", 8, "") == "hello wo" { pass = pass + 1 }
	// Empty result.
	if strings.Truncate("hello", 0, "...") == "" { pass = pass + 1 }
	if strings.Truncate("hello", -1, "...") == "" { pass = pass + 1 }
	// Empty input.
	if strings.Truncate("", 5, "...") == "" { pass = pass + 1 }
	// Ellipsis longer than budget — return ellipsis prefix.
	if strings.Truncate("hello world", 2, "...") == ".." { pass = pass + 1 }
	// Ellipsis equal to budget.
	if strings.Truncate("hello world", 3, "...") == "..." { pass = pass + 1 }

	// FirstRune — ASCII.
	if strings.FirstRune("hello") == "h" { pass = pass + 1 }
	// Empty.
	if strings.FirstRune("") == "" { pass = pass + 1 }
	// Multi-byte é (0xC3 0xA9).
	if strings.FirstRune("\xC3\xA9hello") == "\xC3\xA9" { pass = pass + 1 }
	// Multi-byte 世 (0xE4 0xB8 0x96).
	if strings.FirstRune("\xE4\xB8\x96abc") == "\xE4\xB8\x96" { pass = pass + 1 }
	// 4-byte emoji.
	if strings.FirstRune("\xF0\x9F\x98\x80xyz") == "\xF0\x9F\x98\x80" { pass = pass + 1 }
	// Single ASCII byte.
	if strings.FirstRune("a") == "a" { pass = pass + 1 }

	// LastRune — ASCII.
	if strings.LastRune("hello") == "o" { pass = pass + 1 }
	// Empty.
	if strings.LastRune("") == "" { pass = pass + 1 }
	// Multi-byte at end.
	if strings.LastRune("hello\xC3\xA9") == "\xC3\xA9" { pass = pass + 1 }
	// 4-byte emoji at end.
	if strings.LastRune("abc\xF0\x9F\x98\x80") == "\xF0\x9F\x98\x80" { pass = pass + 1 }
	// Single ASCII.
	if strings.LastRune("z") == "z" { pass = pass + 1 }
	// All same rune (one rune).
	if strings.LastRune("\xC3\xA9") == "\xC3\xA9" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
