package main
import "log"
import "strings"

// Test the new strings.LineRange (1-indexed, paired with LineColAt).
// strings.LineAt already existed but is 0-indexed; not retested here.

fun main() int {
	var pass int = 0

	var src string = "first\nsecond\nthird"

	// LineRange basics.
	if strings.LineRange(src, 1, 2) == "first\nsecond" { pass = pass + 1 }
	if strings.LineRange(src, 2, 3) == "second\nthird" { pass = pass + 1 }
	if strings.LineRange(src, 1, 3) == "first\nsecond\nthird" { pass = pass + 1 }

	// Single-line range.
	if strings.LineRange(src, 2, 2) == "second" { pass = pass + 1 }
	if strings.LineRange(src, 1, 1) == "first" { pass = pass + 1 }
	if strings.LineRange(src, 3, 3) == "third" { pass = pass + 1 }

	// Out-of-range clamps.
	if strings.LineRange(src, 0, 2) == "first\nsecond" { pass = pass + 1 }
	if strings.LineRange(src, -5, 2) == "first\nsecond" { pass = pass + 1 }
	if strings.LineRange(src, 2, 99) == "second\nthird" { pass = pass + 1 }

	// from > to → "".
	if strings.LineRange(src, 3, 1) == "" { pass = pass + 1 }

	// from past end.
	if strings.LineRange(src, 99, 100) == "" { pass = pass + 1 }

	// Empty input.
	if strings.LineRange("", 1, 5) == "" { pass = pass + 1 }

	// Whole range == joined Lines.
	var full string = strings.LineRange(src, 1, 99)
	if full == "first\nsecond\nthird" { pass = pass + 1 }

	// Blank lines preserved.
	if strings.LineRange("a\n\nb", 1, 3) == "a\n\nb" { pass = pass + 1 }
	if strings.LineRange("a\n\nb", 2, 2) == "" { pass = pass + 1 }

	// Trailing newline (Lines yields 2, not 3).
	if strings.LineRange("a\nb\n", 1, 2) == "a\nb" { pass = pass + 1 }

	// CRLF normalization.
	if strings.LineRange("a\r\nb\r\nc", 1, 2) == "a\nb" { pass = pass + 1 }

	// Error-context use case.
	var prog string = "fun main() int {\n  var x = 5\n  ret oops\n}"
	var errLine int = 3
	var context string = strings.LineRange(prog, errLine - 1, errLine + 1)
	if context == "  var x = 5\n  ret oops\n}" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
