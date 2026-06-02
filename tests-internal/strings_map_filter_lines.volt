package main
import "log"
import "strings"

fun upper(s string) string {
	ret strings.ToUpper(s)
}

fun addBullet(s string) string {
	ret "- " + s
}

fun addComment(s string) string {
	ret "// " + s
}

fun nonEmpty(s string) bool {
	if len(s) == 0 { ret false }
	ret true
}

fun isError(s string) bool {
	if strings.HasPrefix(s, "ERROR") { ret true }
	ret false
}

fun anyLine(s string) bool {
	if len(s) >= 0 { ret true }
	ret false
}

fun noLine(s string) bool {
	if len(s) >= 0 { ret false }
	ret false
}

fun main() int {
	var pass int = 0

	// Empty.
	if strings.MapLines("", upper) == "" { pass = pass + 1 }
	if strings.FilterLines("", nonEmpty) == "" { pass = pass + 1 }

	// MapLines uppercase.
	if strings.MapLines("hello\nworld", upper) == "HELLO\nWORLD" { pass = pass + 1 }

	// MapLines bullet-prepend.
	if strings.MapLines("a\nb\nc", addBullet) == "- a\n- b\n- c" { pass = pass + 1 }

	// MapLines comment-prepend (Indent equivalent).
	if strings.MapLines("x = 1\ny = 2", addComment) == "// x = 1\n// y = 2" { pass = pass + 1 }

	// MapLines blank lines pass through fn.
	if strings.MapLines("a\n\nb", addBullet) == "- a\n- \n- b" { pass = pass + 1 }

	// MapLines single line.
	if strings.MapLines("hello", upper) == "HELLO" { pass = pass + 1 }

	// MapLines CRLF normalized.
	if strings.MapLines("a\r\nb", upper) == "A\nB" { pass = pass + 1 }

	// FilterLines: strip blank lines.
	if strings.FilterLines("a\n\nb\n\nc", nonEmpty) == "a\nb\nc" { pass = pass + 1 }
	if strings.FilterLines("\n\n", nonEmpty) == "" { pass = pass + 1 }

	// FilterLines: error-line extraction.
	var logs string = "INFO start\nERROR failed\nINFO ok\nERROR died"
	if strings.FilterLines(logs, isError) == "ERROR failed\nERROR died" { pass = pass + 1 }

	// FilterLines all-pass.
	if strings.FilterLines("a\nb\nc", anyLine) == "a\nb\nc" { pass = pass + 1 }

	// FilterLines all-reject.
	if strings.FilterLines("a\nb\nc", noLine) == "" { pass = pass + 1 }

	// FilterLines single line that's kept.
	if strings.FilterLines("kept", anyLine) == "kept" { pass = pass + 1 }
	if strings.FilterLines("rejected", noLine) == "" { pass = pass + 1 }

	// Composition: filter then map.
	var dirty string = "hello\n\nworld\n\nfoo"
	var cleaned string = strings.FilterLines(dirty, nonEmpty)
	var upper2 string = strings.MapLines(cleaned, upper)
	if upper2 == "HELLO\nWORLD\nFOO" { pass = pass + 1 }

	// Blockquote (markdown-style) use case.
	if strings.MapLines("line1\nline2", addBullet) == "- line1\n- line2" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
