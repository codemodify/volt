package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Basic: line 1 col 1 → "hello\n^".
	if strings.CaretLine("hello", 1, 1) == "hello\n^" { pass = pass + 1 }

	// Line 1 col 3 → "hello\n  ^".
	if strings.CaretLine("hello", 1, 3) == "hello\n  ^" { pass = pass + 1 }

	// Line 1 col 5 → "hello\n    ^".
	if strings.CaretLine("hello", 1, 5) == "hello\n    ^" { pass = pass + 1 }

	// Col past line length.
	if strings.CaretLine("hi", 1, 10) == "hi\n         ^" { pass = pass + 1 }

	// Out of range line.
	if strings.CaretLine("hi", 0, 1) == "" { pass = pass + 1 }
	if strings.CaretLine("hi", -1, 1) == "" { pass = pass + 1 }
	if strings.CaretLine("hi", 2, 1) == "" { pass = pass + 1 }

	// Empty input.
	if strings.CaretLine("", 1, 1) == "" { pass = pass + 1 }

	// Multi-line: pick line 2.
	if strings.CaretLine("first\nsecond\nthird", 2, 1) == "second\n^" { pass = pass + 1 }
	if strings.CaretLine("first\nsecond\nthird", 2, 4) == "second\n   ^" { pass = pass + 1 }

	// Last line.
	if strings.CaretLine("first\nsecond\nthird", 3, 3) == "third\n  ^" { pass = pass + 1 }

	// col < 1 clamps to 1.
	if strings.CaretLine("hello", 1, 0) == "hello\n^" { pass = pass + 1 }
	if strings.CaretLine("hello", 1, -5) == "hello\n^" { pass = pass + 1 }

	// CRLF normalized.
	if strings.CaretLine("a\r\nb", 2, 1) == "b\n^" { pass = pass + 1 }

	// Compiler-error full picture.
	var src string = "fun main() int {\n  var x = 5\n  ret oops\n}"
	// Find "oops" → it starts on line 3.
	var lineNo int = 3
	var col int = 7
	var pointer string = strings.CaretLine(src, lineNo, col)
	if pointer == "  ret oops\n      ^" { pass = pass + 1 }

	// Pair with LineColAt + Excerpt for a full error message.
	var at int = strings.IndexNth(src, "oops", 0)
	if at >= 0 { pass = pass + 1 }
	var line2 int = 0
	var col2 int = 0
	line2, col2 = strings.LineColAt(src, at)
	var lc string = strings.CaretLine(src, line2, col2)
	if lc == "  ret oops\n      ^" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
