package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty.
	if strings.TrimSpaceEachLine("") == "" { pass = pass + 1 }

	// Single line, leading + trailing ws.
	if strings.TrimSpaceEachLine("  hello  ") == "hello" { pass = pass + 1 }

	// Single line, no ws.
	if strings.TrimSpaceEachLine("hello") == "hello" { pass = pass + 1 }

	// Single line, only ws.
	if strings.TrimSpaceEachLine("   \t  ") == "" { pass = pass + 1 }

	// Multi-line, each with surrounding ws.
	if strings.TrimSpaceEachLine("  a  \n  b  \n  c  ") == "a\nb\nc" { pass = pass + 1 }

	// Preserves blank lines as "".
	if strings.TrimSpaceEachLine("a\n\nb") == "a\n\nb" { pass = pass + 1 }

	// Blank lines containing only ws → become "" (not dropped).
	if strings.TrimSpaceEachLine("a\n   \nb") == "a\n\nb" { pass = pass + 1 }

	// Trailing newline preserved.
	if strings.TrimSpaceEachLine("a\n") == "a\n" { pass = pass + 1 }
	if strings.TrimSpaceEachLine("  hello  \n") == "hello\n" { pass = pass + 1 }

	// CRLF handling: '\r' stripped via Lines(), then trim doesn't re-add.
	if strings.TrimSpaceEachLine("  a  \r\n  b  ") == "a\nb" { pass = pass + 1 }

	// Tabs treated as whitespace.
	if strings.TrimSpaceEachLine("\thello\t") == "hello" { pass = pass + 1 }

	// Heredoc / user-pasted block use case.
	var heredoc string = "  first line  \n  second line  \n  third line  "
	var cleaned string = strings.TrimSpaceEachLine(heredoc)
	if cleaned == "first line\nsecond line\nthird line" { pass = pass + 1 }

	// Indent stripping (the most common purpose).
	var indented string = "    line one\n    line two\n    line three"
	if strings.TrimSpaceEachLine(indented) == "line one\nline two\nline three" { pass = pass + 1 }

	// Idempotent: applying twice gives same result.
	var inp string = "  a  \n  b  "
	var first string = strings.TrimSpaceEachLine(inp)
	var second string = strings.TrimSpaceEachLine(first)
	if first == second { pass = pass + 1 }

	// Single newline → both lines empty.
	if strings.TrimSpaceEachLine("\n") == "\n" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
