package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty → (0, 0).
	var lo int = 0
	var hi int = 0
	lo, hi = strings.LineSpan("", 0)
	if lo == 0 { pass = pass + 1 }
	if hi == 0 { pass = pass + 1 }

	// Single line, no newline: byteIdx mid-string returns full span.
	lo, hi = strings.LineSpan("hello", 2)
	if lo == 0 { pass = pass + 1 }
	if hi == 5 { pass = pass + 1 }

	// Single line: byteIdx at end → full span.
	lo, hi = strings.LineSpan("hello", 5)
	if lo == 0 { pass = pass + 1 }
	if hi == 5 { pass = pass + 1 }

	// Multi-line, point at first line.
	// "abc\ndef\nghi"   indexes: 0..2, 4..6, 8..10
	lo, hi = strings.LineSpan("abc\ndef\nghi", 1)
	if lo == 0 { pass = pass + 1 }
	if hi == 3 { pass = pass + 1 }

	// Multi-line, point at second line.
	lo, hi = strings.LineSpan("abc\ndef\nghi", 5)
	if lo == 4 { pass = pass + 1 }
	if hi == 7 { pass = pass + 1 }

	// Multi-line, point at third line.
	lo, hi = strings.LineSpan("abc\ndef\nghi", 9)
	if lo == 8 { pass = pass + 1 }
	if hi == 11 { pass = pass + 1 }

	// At the newline itself (byteIdx == 3 in "abc\ndef") — newline is the
	// "next byte" of line 1, so hi is at the newline (not included).
	lo, hi = strings.LineSpan("abc\ndef", 3)
	if lo == 0 { pass = pass + 1 }
	if hi == 3 { pass = pass + 1 }

	// At the byte just after the newline (start of line 2).
	lo, hi = strings.LineSpan("abc\ndef", 4)
	if lo == 4 { pass = pass + 1 }
	if hi == 7 { pass = pass + 1 }

	// Out-of-range clamping.
	lo, hi = strings.LineSpan("abc\ndef", -5)
	if lo == 0 { pass = pass + 1 }
	if hi == 3 { pass = pass + 1 }
	lo, hi = strings.LineSpan("abc\ndef", 100)
	if lo == 4 { pass = pass + 1 }
	if hi == 7 { pass = pass + 1 }

	// Use case — extract the offending line via LineSpan + Slice.
	var src string = "var x int = 5\nvar y int = 6\nvar z int = ?\n"
	var qIdx int = strings.IndexByte(src, 63)    // '?'
	lo, hi = strings.LineSpan(src, qIdx)
	var line string = strings.Slice(src, lo, hi)
	if line == "var z int = ?" { pass = pass + 1 }

	// Trailing newline as terminator: span doesn't include it.
	lo, hi = strings.LineSpan("abc\n", 1)
	if lo == 0 { pass = pass + 1 }
	if hi == 3 { pass = pass + 1 }

	// All-newlines: each line is empty (hi == lo).
	lo, hi = strings.LineSpan("\n\n\n", 0)
	if hi == 0 { pass = pass + 1 }
	if lo == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 25 { ret 42 }
	ret 0
}
