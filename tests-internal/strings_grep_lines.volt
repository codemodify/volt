package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty.
	if strings.GrepLines("", "x") == "" { pass = pass + 1 }
	if strings.GrepLinesNot("", "x") == "" { pass = pass + 1 }

	// Single line: match.
	if strings.GrepLines("hello", "ell") == "hello" { pass = pass + 1 }
	if strings.GrepLinesNot("hello", "ell") == "" { pass = pass + 1 }

	// Single line: no match.
	if strings.GrepLines("hello", "xyz") == "" { pass = pass + 1 }
	if strings.GrepLinesNot("hello", "xyz") == "hello" { pass = pass + 1 }

	// Multi-line filter.
	if strings.GrepLines("apple\nbanana\ncherry\napricot", "ap") == "apple\napricot" { pass = pass + 1 }
	if strings.GrepLinesNot("apple\nbanana\ncherry\napricot", "ap") == "banana\ncherry" { pass = pass + 1 }

	// Empty pat: Contains("", "") is true → keeps all lines.
	if strings.GrepLines("a\nb\nc", "") == "a\nb\nc" { pass = pass + 1 }
	// And GrepLinesNot with empty pat drops all.
	if strings.GrepLinesNot("a\nb\nc", "") == "" { pass = pass + 1 }

	// Blank lines treated like any other.
	if strings.GrepLines("a\n\nb", "a") == "a" { pass = pass + 1 }
	if strings.GrepLinesNot("a\n\nb", "a") == "\nb" { pass = pass + 1 }

	// CRLF normalized.
	if strings.GrepLines("a\r\nb\r\nab", "a") == "a\nab" { pass = pass + 1 }

	// Log-level filtering use case.
	var logs string = "INFO start\nDEBUG cache miss\nERROR failed\nINFO stop\nERROR died"
	if strings.GrepLines(logs, "ERROR") == "ERROR failed\nERROR died" { pass = pass + 1 }
	var logs2 string = "INFO start\nDEBUG cache miss\nERROR failed\nINFO stop\nERROR died"
	if strings.GrepLinesNot(logs2, "DEBUG") == "INFO start\nERROR failed\nINFO stop\nERROR died" { pass = pass + 1 }

	// Cross-property: Grep + GrepNot partition the input (modulo empty pat).
	var src string = "alpha\nbravo\nbeta\ncharlie\nbat"
	var kept string = strings.GrepLines(src, "b")
	var dropped string = strings.GrepLinesNot(src, "b")
	if kept == "bravo\nbeta\nbat" { pass = pass + 1 }
	if dropped == "alpha\ncharlie" { pass = pass + 1 }

	// Single-char pattern.
	if strings.GrepLines("ab\nbc\nca\nda", "a") == "ab\nca\nda" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
