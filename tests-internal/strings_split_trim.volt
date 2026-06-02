package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// SplitTrim basic.
	var r1 []string = strings.SplitTrim("a, b, c", ",")
	if len(r1) == 3 { pass = pass + 1 }
	if r1[0] == "a" { pass = pass + 1 }
	if r1[1] == "b" { pass = pass + 1 }
	if r1[2] == "c" { pass = pass + 1 }

	// No whitespace → identical to Split.
	var r2 []string = strings.SplitTrim("a,b,c", ",")
	if r2[0] == "a" { pass = pass + 1 }
	if r2[1] == "b" { pass = pass + 1 }
	if r2[2] == "c" { pass = pass + 1 }

	// Tabs.
	var r3 []string = strings.SplitTrim("\ta\t,\tb\t", ",")
	if r3[0] == "a" { pass = pass + 1 }
	if r3[1] == "b" { pass = pass + 1 }

	// Empty cells preserved by SplitTrim.
	var r4 []string = strings.SplitTrim("a, , b", ",")
	if len(r4) == 3 { pass = pass + 1 }
	if r4[0] == "a" { pass = pass + 1 }
	if r4[1] == "" { pass = pass + 1 }
	if r4[2] == "b" { pass = pass + 1 }

	// Single-element (no sep occurrences).
	var r5 []string = strings.SplitTrim("  hello  ", ",")
	if len(r5) == 1 { pass = pass + 1 }
	if r5[0] == "hello" { pass = pass + 1 }

	// SplitTrimNonEmpty drops blanks.
	var r6 []string = strings.SplitTrimNonEmpty("a, , b ,, c", ",")
	if len(r6) == 3 { pass = pass + 1 }
	if r6[0] == "a" { pass = pass + 1 }
	if r6[1] == "b" { pass = pass + 1 }
	if r6[2] == "c" { pass = pass + 1 }

	// SplitTrimNonEmpty with all blanks → empty.
	var r7 []string = strings.SplitTrimNonEmpty(" , , , ", ",")
	if len(r7) == 0 { pass = pass + 1 }

	// SplitTrimNonEmpty single non-empty.
	var r8 []string = strings.SplitTrimNonEmpty("solo", ",")
	if len(r8) == 1 { pass = pass + 1 }
	if r8[0] == "solo" { pass = pass + 1 }

	// CSV-row use case.
	var row string = "  alice  , 30 , engineer , "
	var cells []string = strings.SplitTrim(row, ",")
	if len(cells) == 4 { pass = pass + 1 }
	if cells[0] == "alice" { pass = pass + 1 }
	if cells[1] == "30" { pass = pass + 1 }
	if cells[2] == "engineer" { pass = pass + 1 }
	if cells[3] == "" { pass = pass + 1 }

	// Empty string.
	var r9 []string = strings.SplitTrim("", ",")
	if len(r9) == 1 { pass = pass + 1 }
	if r9[0] == "" { pass = pass + 1 }

	// Multi-char sep.
	var r10 []string = strings.SplitTrim(" a ::: b ::: c ", ":::")
	if len(r10) == 3 { pass = pass + 1 }
	if r10[0] == "a" { pass = pass + 1 }
	if r10[1] == "b" { pass = pass + 1 }
	if r10[2] == "c" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 33 { ret 42 }
	ret 0
}
