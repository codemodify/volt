package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty.
	if strings.Excerpt("", 0, 5) == "|<=here|" { pass = pass + 1 }

	// At position 0.
	if strings.Excerpt("hello world", 0, 3) == "|<=here|hel…" { pass = pass + 1 }

	// At end.
	if strings.Excerpt("hello world", 11, 3) == "…rld|<=here|" { pass = pass + 1 }

	// In middle, radius small.
	if strings.Excerpt("hello world", 5, 2) == "…lo|<=here| w…" { pass = pass + 1 }

	// Whole string fits within radius.
	if strings.Excerpt("hi", 1, 5) == "h|<=here|i" { pass = pass + 1 }

	// Negative position clamps to 0.
	if strings.Excerpt("hello", -3, 2) == "|<=here|he…" { pass = pass + 1 }

	// Position past end clamps to len.
	if strings.Excerpt("hello", 99, 2) == "…lo|<=here|" { pass = pass + 1 }

	// Zero radius.
	if strings.Excerpt("hello", 2, 0) == "|<=here|" { pass = pass + 1 }

	// Negative radius clamps to 0.
	if strings.Excerpt("hello", 2, -5) == "|<=here|" { pass = pass + 1 }

	// LineColAt: position 0 in empty.
	var l1 int = 0
	var c1 int = 0
	l1, c1 = strings.LineColAt("", 0)
	if l1 == 1 { pass = pass + 1 }
	if c1 == 1 { pass = pass + 1 }

	// Position 0 in non-empty.
	var l2 int = 0
	var c2 int = 0
	l2, c2 = strings.LineColAt("hello", 0)
	if l2 == 1 { pass = pass + 1 }
	if c2 == 1 { pass = pass + 1 }

	// Position 5 in "hello" (after).
	var l3 int = 0
	var c3 int = 0
	l3, c3 = strings.LineColAt("hello", 5)
	if l3 == 1 { pass = pass + 1 }
	if c3 == 6 { pass = pass + 1 }

	// After a newline.
	var l4 int = 0
	var c4 int = 0
	l4, c4 = strings.LineColAt("a\nb", 2)
	if l4 == 2 { pass = pass + 1 }
	if c4 == 1 { pass = pass + 1 }

	// Mid-second-line.
	var l5 int = 0
	var c5 int = 0
	l5, c5 = strings.LineColAt("first\nsecond line", 11)
	if l5 == 2 { pass = pass + 1 }
	if c5 == 6 { pass = pass + 1 }   // "s","e","c","o","n" already + at "d"

	// Multi-line.
	var l6 int = 0
	var c6 int = 0
	l6, c6 = strings.LineColAt("a\nb\nc\nd", 4)
	if l6 == 3 { pass = pass + 1 }
	if c6 == 1 { pass = pass + 1 }

	// At newline character.
	var l7 int = 0
	var c7 int = 0
	l7, c7 = strings.LineColAt("a\nb", 1)
	if l7 == 1 { pass = pass + 1 }
	if c7 == 2 { pass = pass + 1 }

	// Out-of-range position clamps.
	var l8 int = 0
	var c8 int = 0
	l8, c8 = strings.LineColAt("ab", -5)
	if l8 == 1 { pass = pass + 1 }
	if c8 == 1 { pass = pass + 1 }
	var l9 int = 0
	var c9 int = 0
	l9, c9 = strings.LineColAt("ab", 99)
	if l9 == 1 { pass = pass + 1 }
	if c9 == 3 { pass = pass + 1 }

	// Error-context use case.
	var src string = "var x = 5\nvar y = oops\nret 0"
	var l10 int = 0
	var c10 int = 0
	l10, c10 = strings.LineColAt(src, 18)   // somewhere in "oops"
	if l10 == 2 { pass = pass + 1 }
	if c10 >= 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
