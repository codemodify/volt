package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Exact multiple.
	if strings.RepeatTo("ab", 6) == "ababab" { pass = pass + 1 }
	if strings.RepeatTo("xyz", 9) == "xyzxyzxyz" { pass = pass + 1 }

	// Truncated to non-multiple length.
	if strings.RepeatTo("abc", 7) == "abcabca" { pass = pass + 1 }
	if strings.RepeatTo("abc", 8) == "abcabcab" { pass = pass + 1 }
	if strings.RepeatTo("xy", 5) == "xyxyx" { pass = pass + 1 }

	// Single char.
	if strings.RepeatTo("-", 10) == "----------" { pass = pass + 1 }
	if strings.RepeatTo("*", 3) == "***" { pass = pass + 1 }

	// Shorter than s — truncates to prefix.
	if strings.RepeatTo("hello", 3) == "hel" { pass = pass + 1 }
	if strings.RepeatTo("hello", 1) == "h" { pass = pass + 1 }

	// Empty s.
	if strings.RepeatTo("", 5) == "" { pass = pass + 1 }
	if strings.RepeatTo("", 0) == "" { pass = pass + 1 }

	// totalLen <= 0.
	if strings.RepeatTo("abc", 0) == "" { pass = pass + 1 }
	if strings.RepeatTo("abc", -3) == "" { pass = pass + 1 }

	// Single-byte filler patterns.
	if strings.RepeatTo("=", 5) == "=====" { pass = pass + 1 }

	// Length matches.
	if len(strings.RepeatTo("ab", 7)) == 7 { pass = pass + 1 }
	if len(strings.RepeatTo("longpattern", 4)) == 4 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
