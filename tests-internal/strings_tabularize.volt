package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty.
	var e [][]string = new(0) [][]string {}
	if strings.Tabularize(e, " | ") == "" { pass = pass + 1 }

	// Single row, single column.
	var r1 [][]string = new(1) [][]string {}
	var row1 []string = new(1) []string { "hello" }
	r1[0] = row1
	if strings.Tabularize(r1, " | ") == "hello" { pass = pass + 1 }

	// Two rows, two columns, aligned.
	var r2 [][]string = new(2) [][]string {}
	var row20 []string = new(2) []string { "name", "age" }
	var row21 []string = new(2) []string { "alice", "30" }
	r2[0] = row20
	r2[1] = row21
	// widths: col0=5 (alice), col1=3 (age)
	if strings.Tabularize(r2, " | ") == "name  | age\nalice | 30" { pass = pass + 1 }

	// Three rows, three columns.
	var r3 [][]string = new(3) [][]string {}
	var r3a []string = new(3) []string { "id", "name", "role" }
	var r3b []string = new(3) []string { "1", "alice", "engineer" }
	var r3c []string = new(3) []string { "200", "bob", "lead" }
	r3[0] = r3a
	r3[1] = r3b
	r3[2] = r3c
	// widths: col0=3, col1=5, col2=8
	var expected3 string = "id  | name  | role\n1   | alice | engineer\n200 | bob   | lead"
	if strings.Tabularize(r3, " | ") == expected3 { pass = pass + 1 }

	// Uneven rows: missing cells treated as "".
	var r4 [][]string = new(2) [][]string {}
	var r4a []string = new(3) []string { "a", "b", "c" }
	var r4b []string = new(1) []string { "x" }
	r4[0] = r4a
	r4[1] = r4b
	// widths: col0=1, col1=1, col2=1
	if strings.Tabularize(r4, " ") == "a b c\nx   " { pass = pass + 1 }

	// Single column, multiple rows.
	var r5 [][]string = new(3) [][]string {}
	var r5a []string = new(1) []string { "alpha" }
	var r5b []string = new(1) []string { "beta" }
	var r5c []string = new(1) []string { "gamma" }
	r5[0] = r5a
	r5[1] = r5b
	r5[2] = r5c
	if strings.Tabularize(r5, " | ") == "alpha\nbeta\ngamma" { pass = pass + 1 }

	// Different separator.
	var r6 [][]string = new(2) [][]string {}
	var r6a []string = new(2) []string { "key", "value" }
	var r6b []string = new(2) []string { "color", "red" }
	r6[0] = r6a
	r6[1] = r6b
	if strings.Tabularize(r6, ": ") == "key  : value\ncolor: red" { pass = pass + 1 }

	// Empty cells.
	var r7 [][]string = new(2) [][]string {}
	var r7a []string = new(2) []string { "", "value" }
	var r7b []string = new(2) []string { "key", "" }
	r7[0] = r7a
	r7[1] = r7b
	if strings.Tabularize(r7, " | ") == "    | value\nkey | " { pass = pass + 1 }

	// Last column unpadded (no trailing spaces).
	var r8 [][]string = new(2) [][]string {}
	var r8a []string = new(2) []string { "a", "long header" }
	var r8b []string = new(2) []string { "long-name", "x" }
	r8[0] = r8a
	r8[1] = r8b
	var result string = strings.Tabularize(r8, " | ")
	// Last cell on row 2 is "x", no trailing pad.
	if result[len(result) - 1] == 120 { pass = pass + 1 }   // 'x' is 120

	log.Println("pass=%d", pass)
	if pass == 9 { ret 42 }
	ret 0
}
