package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty.
	if strings.UniqueLines("") == "" { pass = pass + 1 }
	if strings.SortLines("") == "" { pass = pass + 1 }

	// All distinct: UniqueLines returns input unchanged.
	if strings.UniqueLines("a\nb\nc") == "a\nb\nc" { pass = pass + 1 }

	// Dedupe (order-preserving).
	if strings.UniqueLines("a\nb\na\nc\nb") == "a\nb\nc" { pass = pass + 1 }

	// All-same → single line.
	if strings.UniqueLines("x\nx\nx") == "x" { pass = pass + 1 }

	// Blank lines (treated like any other line).
	if strings.UniqueLines("a\n\nb\n\nc") == "a\n\nb\nc" { pass = pass + 1 }

	// CRLF normalized for Unique.
	if strings.UniqueLines("a\r\nb\r\na") == "a\nb" { pass = pass + 1 }

	// SortLines.
	if strings.SortLines("c\na\nb") == "a\nb\nc" { pass = pass + 1 }
	if strings.SortLines("delta\nalpha\ncharlie\nbravo") == "alpha\nbravo\ncharlie\ndelta" { pass = pass + 1 }

	// SortLines: already sorted → unchanged.
	if strings.SortLines("a\nb\nc") == "a\nb\nc" { pass = pass + 1 }

	// SortLines: reverse.
	if strings.SortLines("z\ny\nx") == "x\ny\nz" { pass = pass + 1 }

	// SortLines: duplicates preserved.
	if strings.SortLines("c\na\nb\na") == "a\na\nb\nc" { pass = pass + 1 }

	// SortLines: single line.
	if strings.SortLines("only") == "only" { pass = pass + 1 }

	// SortLines CRLF normalized.
	if strings.SortLines("c\r\na\r\nb") == "a\nb\nc" { pass = pass + 1 }

	// Sort + Unique composition: sorted unique.
	var raw string = "delta\nalpha\nbravo\nalpha\ncharlie\nbravo"
	var u string = strings.UniqueLines(raw)
	var sorted string = strings.SortLines(u)
	if sorted == "alpha\nbravo\ncharlie\ndelta" { pass = pass + 1 }

	// Log-dedup use case.
	var logs string = "INFO start\nWARN slow\nINFO start\nERROR oops\nWARN slow"
	if strings.UniqueLines(logs) == "INFO start\nWARN slow\nERROR oops" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
