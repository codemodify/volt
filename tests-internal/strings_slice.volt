package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Slice — basic range.
	if strings.Slice("hello world", 0, 5) == "hello" { pass = pass + 1 }
	if strings.Slice("hello world", 6, 11) == "world" { pass = pass + 1 }
	if strings.Slice("hello world", 0, 11) == "hello world" { pass = pass + 1 }

	// Slice — single character.
	if strings.Slice("hello", 0, 1) == "h" { pass = pass + 1 }
	if strings.Slice("hello", 4, 5) == "o" { pass = pass + 1 }

	// Slice — empty result.
	if strings.Slice("hello", 0, 0) == "" { pass = pass + 1 }
	if strings.Slice("hello", 2, 2) == "" { pass = pass + 1 }
	if strings.Slice("hello", 3, 1) == "" { pass = pass + 1 }     // hi < lo

	// Slice — empty input.
	if strings.Slice("", 0, 5) == "" { pass = pass + 1 }
	if strings.Slice("", 0, 0) == "" { pass = pass + 1 }

	// Slice — bounds clamping.
	if strings.Slice("hello", -5, 5) == "hello" { pass = pass + 1 }
	if strings.Slice("hello", 0, 100) == "hello" { pass = pass + 1 }
	if strings.Slice("hello", -100, 100) == "hello" { pass = pass + 1 }
	if strings.Slice("hello", 2, 100) == "llo" { pass = pass + 1 }

	// Slice — used with Index for substring extraction.
	var s string = "name=alice&age=30"
	var sep int = strings.IndexByte(s, 61)    // '='
	if sep == 4 { pass = pass + 1 }
	if strings.Slice(s, 0, sep) == "name" { pass = pass + 1 }
	if strings.Slice(s, sep + 1, 10) == "alice" { pass = pass + 1 }

	// Slice — used with Index for substring after match.
	var amp int = strings.IndexByte(s, 38)    // '&'
	if amp == 10 { pass = pass + 1 }
	if strings.Slice(s, amp + 1, len(s)) == "age=30" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
