package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty.
	if strings.HeadLines("", 5) == "" { pass = pass + 1 }
	if strings.TailLines("", 5) == "" { pass = pass + 1 }

	// n <= 0 → "".
	if strings.HeadLines("a\nb\nc", 0) == "" { pass = pass + 1 }
	if strings.HeadLines("a\nb\nc", -1) == "" { pass = pass + 1 }
	if strings.TailLines("a\nb\nc", 0) == "" { pass = pass + 1 }
	if strings.TailLines("a\nb\nc", -1) == "" { pass = pass + 1 }

	// Three-line content.
	if strings.HeadLines("a\nb\nc", 1) == "a" { pass = pass + 1 }
	if strings.HeadLines("a\nb\nc", 2) == "a\nb" { pass = pass + 1 }
	if strings.HeadLines("a\nb\nc", 3) == "a\nb\nc" { pass = pass + 1 }

	if strings.TailLines("a\nb\nc", 1) == "c" { pass = pass + 1 }
	if strings.TailLines("a\nb\nc", 2) == "b\nc" { pass = pass + 1 }
	if strings.TailLines("a\nb\nc", 3) == "a\nb\nc" { pass = pass + 1 }

	// n > number-of-lines → all.
	if strings.HeadLines("a\nb", 99) == "a\nb" { pass = pass + 1 }
	if strings.TailLines("a\nb", 99) == "a\nb" { pass = pass + 1 }

	// Single-line input.
	if strings.HeadLines("only", 5) == "only" { pass = pass + 1 }
	if strings.TailLines("only", 5) == "only" { pass = pass + 1 }

	// Trailing newline.
	// "a\nb\n" → Lines() yields ["a","b"] (trailing nl not a phantom 3rd line)
	if strings.HeadLines("a\nb\n", 1) == "a" { pass = pass + 1 }
	if strings.TailLines("a\nb\n", 1) == "b" { pass = pass + 1 }

	// CRLF normalization (Lines strips \r).
	if strings.HeadLines("a\r\nb\r\nc", 2) == "a\nb" { pass = pass + 1 }
	if strings.TailLines("a\r\nb\r\nc", 1) == "c" { pass = pass + 1 }

	// `head -5` use case.
	var lf string = "L1\nL2\nL3\nL4\nL5\nL6\nL7\nL8\nL9\nL10"
	if strings.HeadLines(lf, 5) == "L1\nL2\nL3\nL4\nL5" { pass = pass + 1 }

	// `tail -3` use case.
	var lf2 string = "L1\nL2\nL3\nL4\nL5\nL6\nL7\nL8\nL9\nL10"
	if strings.TailLines(lf2, 3) == "L8\nL9\nL10" { pass = pass + 1 }

	// Blank lines preserved.
	if strings.HeadLines("a\n\nb", 2) == "a\n" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
