package main
import "log"
import "strings"

// Positive test: strings.Lines — top-level line splitter (mirrors
// bufio.SplitLines but lives in `strings` for ergonomic discovery).

fun main() int {
	var pass int = 0

	// LF lines.
	var l1 []string = strings.Lines("alpha\nbeta\ngamma")
	if len(l1) == 3 { pass = pass + 1 }
	if l1[0] == "alpha" { pass = pass + 1 }
	if l1[2] == "gamma" { pass = pass + 1 }

	// CRLF lines.
	var l2 []string = strings.Lines("foo\r\nbar\r\nbaz")
	if len(l2) == 3 { pass = pass + 1 }
	if l2[1] == "bar" { pass = pass + 1 }

	// Mixed LF + CRLF.
	var l3 []string = strings.Lines("one\ntwo\r\nthree")
	if len(l3) == 3 { pass = pass + 1 }

	// Empty input.
	if len(strings.Lines("")) == 0 { pass = pass + 1 }

	// Trailing newline → trailing piece dropped (consistent with
	// `read-then-split-on-\n` semantics).
	var l4 []string = strings.Lines("hi\n")
	if len(l4) == 1 { pass = pass + 1 }
	if l4[0] == "hi" { pass = pass + 1 }

	// Single line.
	var l5 []string = strings.Lines("solo")
	if len(l5) == 1 { pass = pass + 1 }
	if l5[0] == "solo" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 11 { ret 42 }
	ret 0
}
