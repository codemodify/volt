package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty.
	if strings.NumberLines("") == "" { pass = pass + 1 }
	if strings.ReverseLines("") == "" { pass = pass + 1 }

	// Single line.
	if strings.NumberLines("hello") == "1\thello" { pass = pass + 1 }
	if strings.ReverseLines("hello") == "hello" { pass = pass + 1 }

	// Three lines.
	if strings.NumberLines("a\nb\nc") == "1\ta\n2\tb\n3\tc" { pass = pass + 1 }
	if strings.ReverseLines("a\nb\nc") == "c\nb\na" { pass = pass + 1 }

	// Two lines.
	if strings.NumberLines("first\nsecond") == "1\tfirst\n2\tsecond" { pass = pass + 1 }
	if strings.ReverseLines("first\nsecond") == "second\nfirst" { pass = pass + 1 }

	// Trailing newline (Lines yields 2 entries, not 3).
	if strings.NumberLines("a\nb\n") == "1\ta\n2\tb" { pass = pass + 1 }
	if strings.ReverseLines("a\nb\n") == "b\na" { pass = pass + 1 }

	// Blank lines preserved.
	if strings.NumberLines("a\n\nb") == "1\ta\n2\t\n3\tb" { pass = pass + 1 }
	if strings.ReverseLines("a\n\nb") == "b\n\na" { pass = pass + 1 }

	// CRLF normalized.
	if strings.NumberLines("a\r\nb\r\nc") == "1\ta\n2\tb\n3\tc" { pass = pass + 1 }
	if strings.ReverseLines("a\r\nb\r\nc") == "c\nb\na" { pass = pass + 1 }

	// ReverseLines is its own inverse.
	var inp string = "line1\nline2\nline3\nline4"
	var rev1 string = strings.ReverseLines(inp)
	var rev2 string = strings.ReverseLines(rev1)
	if rev2 == "line1\nline2\nline3\nline4" { pass = pass + 1 }

	// 10-line case to exercise multi-digit numbers.
	var ten string = "l1\nl2\nl3\nl4\nl5\nl6\nl7\nl8\nl9\nl10"
	var numbered string = strings.NumberLines(ten)
	// Contains "10\tl10".
	if strings.Contains(numbered, "10\tl10") { pass = pass + 1 }
	if strings.Contains(numbered, "1\tl1") { pass = pass + 1 }
	if strings.Contains(numbered, "9\tl9") { pass = pass + 1 }

	// Code-listing use case.
	var src string = "fun main() int {\n  ret 42\n}"
	var listed string = strings.NumberLines(src)
	if listed == "1\tfun main() int {\n2\t  ret 42\n3\t}" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
