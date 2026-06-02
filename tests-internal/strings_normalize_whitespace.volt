package main
import "log"
import "strings"

// Positive test: strings.NormalizeWhitespace.

fun main() int {
	var pass int = 0

	// Basic collapse.
	if strings.NormalizeWhitespace("hello   world") == "hello world" { pass = pass + 1 }
	// Leading whitespace stripped.
	if strings.NormalizeWhitespace("   hello") == "hello" { pass = pass + 1 }
	// Trailing whitespace stripped.
	if strings.NormalizeWhitespace("hello   ") == "hello" { pass = pass + 1 }
	// Both sides + middle.
	if strings.NormalizeWhitespace("   a   b   ") == "a b" { pass = pass + 1 }
	// Tabs collapse with spaces to a single space.
	if strings.NormalizeWhitespace("a\t\tb") == "a b" { pass = pass + 1 }
	// Newlines and CR collapse.
	if strings.NormalizeWhitespace("foo\n\nbar") == "foo bar" { pass = pass + 1 }
	if strings.NormalizeWhitespace("foo\r\nbar") == "foo bar" { pass = pass + 1 }
	// Mixed whitespace runs collapse.
	if strings.NormalizeWhitespace("a \t\n  b") == "a b" { pass = pass + 1 }
	// Single token — no whitespace produced.
	if strings.NormalizeWhitespace("hello") == "hello" { pass = pass + 1 }
	// Already normalized.
	if strings.NormalizeWhitespace("hello world foo") == "hello world foo" { pass = pass + 1 }
	// Empty.
	if strings.NormalizeWhitespace("") == "" { pass = pass + 1 }
	// All whitespace.
	if strings.NormalizeWhitespace("   ") == "" { pass = pass + 1 }
	if strings.NormalizeWhitespace("\t\n\r ") == "" { pass = pass + 1 }
	// Single-space input.
	if strings.NormalizeWhitespace(" ") == "" { pass = pass + 1 }
	// Three words varied whitespace.
	if strings.NormalizeWhitespace(" \tone   two\nthree\r\n") == "one two three" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
