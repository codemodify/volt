package main
import "log"
import "strings"

// Positive test: strings.SplitAfter — split keeping the separator
// at the end of each piece. Mirrors Go's strings.SplitAfter.

fun main() int {
	var pass int = 0

	// "a,b,c" by "," → ["a,", "b,", "c"]
	var p1 []string = strings.SplitAfter("a,b,c", ",")
	if len(p1) == 3 { pass = pass + 1 }
	if p1[0] == "a," { pass = pass + 1 }
	if p1[1] == "b," { pass = pass + 1 }
	if p1[2] == "c" { pass = pass + 1 }

	// Trailing sep: "a,b," → ["a,", "b,"]
	var p2 []string = strings.SplitAfter("a,b,", ",")
	if len(p2) == 2 { pass = pass + 1 }
	if p2[1] == "b," { pass = pass + 1 }

	// Empty sep → single-element slice containing s.
	var p3 []string = strings.SplitAfter("abc", "")
	if len(p3) == 1 { pass = pass + 1 }
	if p3[0] == "abc" { pass = pass + 1 }

	// Sep not in s → single-element result.
	var p4 []string = strings.SplitAfter("hello", "x")
	if len(p4) == 1 { pass = pass + 1 }
	if p4[0] == "hello" { pass = pass + 1 }

	// Multi-byte sep.
	var p5 []string = strings.SplitAfter("aXYbXYc", "XY")
	if len(p5) == 3 { pass = pass + 1 }
	if p5[0] == "aXY" { pass = pass + 1 }
	if p5[1] == "bXY" { pass = pass + 1 }
	if p5[2] == "c" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
