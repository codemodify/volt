package main
import "log"
import "strings"

// Positive test: strings.LineCount + strings.LineAt.

fun main() int {
	var pass int = 0

	// LineCount basic.
	if strings.LineCount("") == 0 { pass = pass + 1 }
	if strings.LineCount("hello") == 1 { pass = pass + 1 }
	if strings.LineCount("hello\n") == 1 { pass = pass + 1 }
	if strings.LineCount("a\nb") == 2 { pass = pass + 1 }
	if strings.LineCount("a\nb\n") == 2 { pass = pass + 1 }
	if strings.LineCount("a\nb\nc") == 3 { pass = pass + 1 }
	if strings.LineCount("a\nb\nc\n") == 3 { pass = pass + 1 }

	// Just newline — terminates one empty line.
	if strings.LineCount("\n") == 1 { pass = pass + 1 }

	// Multiple consecutive newlines (each separates a line).
	if strings.LineCount("a\n\nb") == 3 { pass = pass + 1 }   // a, empty, b
	if strings.LineCount("\n\n") == 2 { pass = pass + 1 }     // two empty lines terminated

	// LineAt basic.
	var s string = "first\nsecond\nthird"
	if strings.LineAt(s, 0) == "first" { pass = pass + 1 }
	if strings.LineAt(s, 1) == "second" { pass = pass + 1 }
	if strings.LineAt(s, 2) == "third" { pass = pass + 1 }

	// LineAt out-of-range.
	if strings.LineAt(s, 3) == "" { pass = pass + 1 }
	if strings.LineAt(s, -1) == "" { pass = pass + 1 }
	if strings.LineAt(s, 100) == "" { pass = pass + 1 }

	// LineAt with trailing newline.
	var t string = "a\nb\n"
	if strings.LineAt(t, 0) == "a" { pass = pass + 1 }
	if strings.LineAt(t, 1) == "b" { pass = pass + 1 }
	if strings.LineAt(t, 2) == "" { pass = pass + 1 }   // past last line

	// LineAt single line.
	if strings.LineAt("only", 0) == "only" { pass = pass + 1 }
	if strings.LineAt("only", 1) == "" { pass = pass + 1 }

	// LineAt empty string.
	if strings.LineAt("", 0) == "" { pass = pass + 1 }

	// LineAt blank-line in middle.
	var u string = "a\n\nb"
	if strings.LineAt(u, 0) == "a" { pass = pass + 1 }
	if strings.LineAt(u, 1) == "" { pass = pass + 1 }   // blank
	if strings.LineAt(u, 2) == "b" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 25 { ret 42 }
	ret 0
}
