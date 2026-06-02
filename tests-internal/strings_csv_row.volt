package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// CsvJoinRow — basic plain values.
	if strings.CsvJoinRow(new(3) []string { "a", "b", "c" }) == "a,b,c" { pass = pass + 1 }

	// CsvJoinRow — empty cells preserved.
	if strings.CsvJoinRow(new(3) []string { "a", "", "c" }) == "a,,c" { pass = pass + 1 }

	// CsvJoinRow — cells with comma get quoted.
	if strings.CsvJoinRow(new(2) []string { "a,b", "c" }) == "\"a,b\",c" { pass = pass + 1 }

	// CsvJoinRow — cells with quotes get escaped.
	if strings.CsvJoinRow(new(1) []string { "a\"b" }) == "\"a\"\"b\"" { pass = pass + 1 }

	// CsvJoinRow — single cell.
	if strings.CsvJoinRow(new(1) []string { "alone" }) == "alone" { pass = pass + 1 }

	// CsvJoinRow — empty input.
	if strings.CsvJoinRow(new(0) []string {}) == "" { pass = pass + 1 }

	// CsvSplitRow — basic.
	var r1 []string = strings.CsvSplitRow("a,b,c")
	if len(r1) == 3 { pass = pass + 1 }
	if r1[0] == "a" { pass = pass + 1 }
	if r1[1] == "b" { pass = pass + 1 }
	if r1[2] == "c" { pass = pass + 1 }

	// CsvSplitRow — empty cells.
	var r2 []string = strings.CsvSplitRow("a,,c")
	if len(r2) == 3 { pass = pass + 1 }
	if r2[1] == "" { pass = pass + 1 }

	// CsvSplitRow — quoted cell with comma.
	var r3 []string = strings.CsvSplitRow("\"a,b\",c")
	if len(r3) == 2 { pass = pass + 1 }
	if r3[0] == "a,b" { pass = pass + 1 }
	if r3[1] == "c" { pass = pass + 1 }

	// CsvSplitRow — quoted cell with quote doubling.
	var r4 []string = strings.CsvSplitRow("\"say \"\"hi\"\"\"")
	if len(r4) == 1 { pass = pass + 1 }
	if r4[0] == "say \"hi\"" { pass = pass + 1 }

	// CsvSplitRow — empty.
	var r5 []string = strings.CsvSplitRow("")
	if len(r5) == 0 { pass = pass + 1 }

	// CsvSplitRow — single empty quoted cell.
	var r6 []string = strings.CsvSplitRow("\"\"")
	if len(r6) == 1 { pass = pass + 1 }
	if r6[0] == "" { pass = pass + 1 }

	// Roundtrip: CsvSplitRow(CsvJoinRow(cells)) == cells.
	var cells []string = new(3) []string { "a,b", "say \"hi\"", "plain" }
	var roundtrip []string = strings.CsvSplitRow(strings.CsvJoinRow(cells))
	if len(roundtrip) == 3 { pass = pass + 1 }
	if roundtrip[0] == "a,b" { pass = pass + 1 }
	if roundtrip[1] == "say \"hi\"" { pass = pass + 1 }
	if roundtrip[2] == "plain" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
