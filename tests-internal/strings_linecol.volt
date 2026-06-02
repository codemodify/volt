package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty input + byteIdx=0 → (1, 1).
	var line int = 0
	var col int = 0
	line, col = strings.LineCol("", 0)
	if line == 1 { pass = pass + 1 }
	if col == 1 { pass = pass + 1 }

	// Single-line: each byte advances col, line stays 1.
	line, col = strings.LineCol("abc", 0)
	if line == 1 { pass = pass + 1 }
	if col == 1 { pass = pass + 1 }
	line, col = strings.LineCol("abc", 1)
	if col == 2 { pass = pass + 1 }
	line, col = strings.LineCol("abc", 2)
	if col == 3 { pass = pass + 1 }
	line, col = strings.LineCol("abc", 3)        // just past end
	if line == 1 { pass = pass + 1 }
	if col == 4 { pass = pass + 1 }

	// After a newline: line advances, col resets.
	// "abc\nxyz" indexes:  0 1 2 3  4 5 6
	line, col = strings.LineCol("abc\nxyz", 3)
	if line == 1 { pass = pass + 1 }
	if col == 4 { pass = pass + 1 }
	line, col = strings.LineCol("abc\nxyz", 4)
	if line == 2 { pass = pass + 1 }
	if col == 1 { pass = pass + 1 }
	line, col = strings.LineCol("abc\nxyz", 5)
	if line == 2 { pass = pass + 1 }
	if col == 2 { pass = pass + 1 }
	line, col = strings.LineCol("abc\nxyz", 6)
	if line == 2 { pass = pass + 1 }
	if col == 3 { pass = pass + 1 }

	// Multiple newlines.
	// "a\nb\nc\nd"  indexes: 0 1 2 3 4 5 6
	line, col = strings.LineCol("a\nb\nc\nd", 6)
	if line == 4 { pass = pass + 1 }
	if col == 1 { pass = pass + 1 }

	// Bound clamping — negative.
	line, col = strings.LineCol("abc", -5)
	if line == 1 { pass = pass + 1 }
	if col == 1 { pass = pass + 1 }

	// Bound clamping — past end.
	line, col = strings.LineCol("abc\ndef", 100)
	if line == 2 { pass = pass + 1 }
	if col == 4 { pass = pass + 1 }    // past 'f'

	// Use case — typical error report.
	var src string = "var x int = 5\nvar y int = 6\nvar z int = ?\n"
	var qIdx int = strings.IndexByte(src, 63)    // '?'
	if qIdx == 40 { pass = pass + 1 }
	line, col = strings.LineCol(src, qIdx)
	if line == 3 { pass = pass + 1 }
	if col == 13 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 25 { ret 42 }
	ret 0
}
