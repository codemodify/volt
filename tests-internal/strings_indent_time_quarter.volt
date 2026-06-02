package main
import "log"
import "strings"
import "time"

// Positive test: strings.Indent + (t Time).Quarter.

fun main() int {
	var pass int = 0

	// Indent — single line no newline.
	if strings.Indent("hello", "> ") == "> hello" { pass = pass + 1 }

	// Indent — single line with newline.
	if strings.Indent("hello\n", "> ") == "> hello\n" { pass = pass + 1 }

	// Indent — two lines.
	if strings.Indent("foo\nbar", "  ") == "  foo\n  bar" { pass = pass + 1 }

	// Indent — three lines with trailing newline.
	if strings.Indent("a\nb\nc\n", "* ") == "* a\n* b\n* c\n" { pass = pass + 1 }

	// Indent — empty string.
	if strings.Indent("", "X") == "" { pass = pass + 1 }

	// Indent — empty prefix → unchanged.
	if strings.Indent("foo\nbar", "") == "foo\nbar" { pass = pass + 1 }

	// Indent — multiple blank lines between non-blank.
	if strings.Indent("a\n\nb", "# ") == "# a\n# \n# b" { pass = pass + 1 }

	// Indent — only newline.
	if strings.Indent("\n", "X ") == "X \n" { pass = pass + 1 }

	// Quarter — every quarter.
	if time.Date(2024, 1, 15, 0, 0, 0, 0).Quarter() == 1 { pass = pass + 1 }
	if time.Date(2024, 2, 15, 0, 0, 0, 0).Quarter() == 1 { pass = pass + 1 }
	if time.Date(2024, 3, 15, 0, 0, 0, 0).Quarter() == 1 { pass = pass + 1 }
	if time.Date(2024, 4, 15, 0, 0, 0, 0).Quarter() == 2 { pass = pass + 1 }
	if time.Date(2024, 5, 15, 0, 0, 0, 0).Quarter() == 2 { pass = pass + 1 }
	if time.Date(2024, 6, 15, 0, 0, 0, 0).Quarter() == 2 { pass = pass + 1 }
	if time.Date(2024, 7, 15, 0, 0, 0, 0).Quarter() == 3 { pass = pass + 1 }
	if time.Date(2024, 8, 15, 0, 0, 0, 0).Quarter() == 3 { pass = pass + 1 }
	if time.Date(2024, 9, 15, 0, 0, 0, 0).Quarter() == 3 { pass = pass + 1 }
	if time.Date(2024, 10, 15, 0, 0, 0, 0).Quarter() == 4 { pass = pass + 1 }
	if time.Date(2024, 11, 15, 0, 0, 0, 0).Quarter() == 4 { pass = pass + 1 }
	if time.Date(2024, 12, 15, 0, 0, 0, 0).Quarter() == 4 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
