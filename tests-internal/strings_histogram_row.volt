package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Basic.
	var r1 string = strings.AsciiHistogramRow("alice", 10, 7, 20, 35, 46)
	// Expect: "alice     " (10 chars) + " | " + 7×'#' + 13×'.'
	if r1 == "alice      | #######............." { pass = pass + 1 }

	// Label exactly labelWidth.
	var r2 string = strings.AsciiHistogramRow("bob", 3, 3, 5, 35, 46)
	if r2 == "bob | ###.." { pass = pass + 1 }

	// Label longer than labelWidth → not truncated (PadRight no-op when len>=n).
	var r3 string = strings.AsciiHistogramRow("verylongname", 5, 2, 4, 35, 46)
	if strings.Contains(r3, "verylongname") { pass = pass + 1 }
	if strings.Contains(r3, " | ##..") { pass = pass + 1 }

	// Empty label.
	var r4 string = strings.AsciiHistogramRow("", 5, 3, 5, 35, 46)
	if r4 == "      | ###.." { pass = pass + 1 }   // 5 spaces + " | " + "###.."

	// Zero count.
	var r5 string = strings.AsciiHistogramRow("zero", 5, 0, 5, 35, 46)
	if r5 == "zero  | ....." { pass = pass + 1 }

	// Full bar.
	var r6 string = strings.AsciiHistogramRow("full", 5, 5, 5, 35, 46)
	if r6 == "full  | #####" { pass = pass + 1 }

	// Count > width clamps.
	var r7 string = strings.AsciiHistogramRow("over", 5, 99, 5, 35, 46)
	if r7 == "over  | #####" { pass = pass + 1 }

	// Zero bar width.
	var r8 string = strings.AsciiHistogramRow("nobars", 8, 3, 0, 35, 46)
	if r8 == "nobars   | " { pass = pass + 1 }

	// Different fill / empty.
	var r9 string = strings.AsciiHistogramRow("x", 3, 3, 5, 42, 32)
	if r9 == "x   | ***  " { pass = pass + 1 }

	// Composed dashboard use case (3 rows).
	var rA string = strings.AsciiHistogramRow("alpha", 7, 4, 10, 35, 46)
	var rB string = strings.AsciiHistogramRow("bravo", 7, 7, 10, 35, 46)
	var rC string = strings.AsciiHistogramRow("charlie", 7, 10, 10, 35, 46)
	if rA == "alpha   | ####......" { pass = pass + 1 }
	if rB == "bravo   | #######..." { pass = pass + 1 }
	if rC == "charlie | ##########" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
