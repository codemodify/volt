package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// NthField on whitespace.
	if strings.NthField("alpha bravo charlie", 0) == "alpha" { pass = pass + 1 }
	if strings.NthField("alpha bravo charlie", 1) == "bravo" { pass = pass + 1 }
	if strings.NthField("alpha bravo charlie", 2) == "charlie" { pass = pass + 1 }
	if strings.NthField("alpha bravo charlie", 3) == "" { pass = pass + 1 }

	// Empty / blank input.
	if strings.NthField("", 0) == "" { pass = pass + 1 }
	if strings.NthField("   ", 0) == "" { pass = pass + 1 }

	// Single field.
	if strings.NthField("only", 0) == "only" { pass = pass + 1 }
	if strings.NthField("only", 1) == "" { pass = pass + 1 }

	// Leading + trailing + multi-space (collapsed).
	if strings.NthField("  a  b  c  ", 0) == "a" { pass = pass + 1 }
	if strings.NthField("  a  b  c  ", 1) == "b" { pass = pass + 1 }
	if strings.NthField("  a  b  c  ", 2) == "c" { pass = pass + 1 }

	// Tabs treated as whitespace.
	if strings.NthField("a\tb\tc", 1) == "b" { pass = pass + 1 }
	if strings.NthField("a\nb\nc", 2) == "c" { pass = pass + 1 }

	// n < 0.
	if strings.NthField("a b c", -1) == "" { pass = pass + 1 }

	// NthFieldSep with comma.
	if strings.NthFieldSep("alpha,bravo,charlie", 44, 0) == "alpha" { pass = pass + 1 }
	if strings.NthFieldSep("alpha,bravo,charlie", 44, 1) == "bravo" { pass = pass + 1 }
	if strings.NthFieldSep("alpha,bravo,charlie", 44, 2) == "charlie" { pass = pass + 1 }
	if strings.NthFieldSep("alpha,bravo,charlie", 44, 3) == "" { pass = pass + 1 }

	// Empty fields preserved with NthFieldSep.
	if strings.NthFieldSep("a,,b", 44, 0) == "a" { pass = pass + 1 }
	if strings.NthFieldSep("a,,b", 44, 1) == "" { pass = pass + 1 }
	if strings.NthFieldSep("a,,b", 44, 2) == "b" { pass = pass + 1 }

	// Leading/trailing separator → empty fields.
	if strings.NthFieldSep(",x,", 44, 0) == "" { pass = pass + 1 }
	if strings.NthFieldSep(",x,", 44, 1) == "x" { pass = pass + 1 }
	if strings.NthFieldSep(",x,", 44, 2) == "" { pass = pass + 1 }

	// Tab-separated record.
	if strings.NthFieldSep("col1\tcol2\tcol3", 9, 1) == "col2" { pass = pass + 1 }

	// Single token w/ no separator.
	if strings.NthFieldSep("solo", 44, 0) == "solo" { pass = pass + 1 }
	if strings.NthFieldSep("solo", 44, 1) == "" { pass = pass + 1 }

	// Cross-property: NthField(s, n) == Fields(s)[n] when valid.
	var s string = "the quick brown fox"
	var fs []string = strings.Fields(s)
	if strings.NthField(s, 2) == fs[2] { pass = pass + 1 }

	// awk-style use case.
	var logl string = "2026-05-28 INFO server started on port 8080"
	if strings.NthField(logl, 1) == "INFO" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 29 { ret 42 }
	ret 0
}
