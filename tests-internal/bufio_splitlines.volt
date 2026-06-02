package main
import "log"
import "bufio"

// Positive test: bufio.SplitLines — split on '\n' boundaries with
// '\r' stripped from each line (handles both LF and CRLF line
// endings).

fun main() int {
	var pass int = 0

	// LF lines.
	var s1 string = "line1\nline2\nline3"
	var l1 []string = bufio.SplitLines(s1)
	if len(l1) == 3 { pass = pass + 1 }
	if l1[0] == "line1" { pass = pass + 1 }
	if l1[1] == "line2" { pass = pass + 1 }
	if l1[2] == "line3" { pass = pass + 1 }

	// CRLF lines.
	var s2 string = "a\r\nb\r\nc"
	var l2 []string = bufio.SplitLines(s2)
	if len(l2) == 3 { pass = pass + 1 }
	if l2[0] == "a" { pass = pass + 1 }
	if l2[1] == "b" { pass = pass + 1 }
	if l2[2] == "c" { pass = pass + 1 }

	// Mixed LF + CRLF.
	var s3 string = "x\ny\r\nz"
	var l3 []string = bufio.SplitLines(s3)
	if len(l3) == 3 { pass = pass + 1 }
	if l3[0] == "x" { pass = pass + 1 }
	if l3[1] == "y" { pass = pass + 1 }

	// Trailing newline produces a trailing empty piece.
	var s4 string = "hi\n"
	var l4 []string = bufio.SplitLines(s4)
	if len(l4) == 1 { pass = pass + 1 }
	if l4[0] == "hi" { pass = pass + 1 }

	// Empty input.
	var l5 []string = bufio.SplitLines("")
	if len(l5) == 0 { pass = pass + 1 }

	// Single line, no terminator.
	var l6 []string = bufio.SplitLines("solo")
	if len(l6) == 1 { pass = pass + 1 }
	if l6[0] == "solo" { pass = pass + 1 }

	// Empty middle line.
	var s7 string = "a\n\nb"
	var l7 []string = bufio.SplitLines(s7)
	if len(l7) == 3 { pass = pass + 1 }
	if l7[1] == "" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
