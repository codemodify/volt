package main
import "log"
import "slices"

// Positive test: slices.ScanInt + slices.ScanString.

fun add(a int, b int) int { ret a + b }
fun mul(a int, b int) int { ret a * b }
fun maxInt(a int, b int) int { if b > a { ret b }; ret a }
fun concat(a string, b string) string { ret a + b }

fun main() int {
	var pass int = 0

	// ScanInt — running sum.
	var a []int = new(5) []int{1, 2, 3, 4, 5}
	var ssum []int = slices.ScanInt(a, 0, add)
	if len(ssum) == 5 { pass = pass + 1 }
	if ssum[0] == 1 { pass = pass + 1 }
	if ssum[1] == 3 { pass = pass + 1 }
	if ssum[2] == 6 { pass = pass + 1 }
	if ssum[3] == 10 { pass = pass + 1 }
	if ssum[4] == 15 { pass = pass + 1 }

	// ScanInt — running product starting at 1.
	var sprod []int = slices.ScanInt(a, 1, mul)
	if sprod[0] == 1 { pass = pass + 1 }   // 1 * 1
	if sprod[1] == 2 { pass = pass + 1 }
	if sprod[4] == 120 { pass = pass + 1 } // 5!

	// ScanInt — running max from -infinity-ish.
	var b []int = new(5) []int{3, 1, 4, 1, 5}
	var smax []int = slices.ScanInt(b, -999, maxInt)
	if smax[0] == 3 { pass = pass + 1 }
	if smax[1] == 3 { pass = pass + 1 }
	if smax[2] == 4 { pass = pass + 1 }
	if smax[3] == 4 { pass = pass + 1 }
	if smax[4] == 5 { pass = pass + 1 }

	// ScanInt — last entry equals total reduce sum.
	var sCheck []int = slices.ScanInt(a, 0, add)
	if sCheck[4] == 15 { pass = pass + 1 }

	// ScanInt — empty.
	var e []int = new(0) []int{}
	if len(slices.ScanInt(e, 100, add)) == 0 { pass = pass + 1 }

	// ScanString — running concat.
	var s []string = new(3) []string{"a", "b", "c"}
	var scc []string = slices.ScanString(s, "", concat)
	if len(scc) == 3 { pass = pass + 1 }
	if scc[0] == "a" { pass = pass + 1 }
	if scc[1] == "ab" { pass = pass + 1 }
	if scc[2] == "abc" { pass = pass + 1 }

	// ScanString — prefix init.
	var scp []string = slices.ScanString(s, ">", concat)
	if scp[0] == ">a" { pass = pass + 1 }
	if scp[2] == ">abc" { pass = pass + 1 }

	// ScanString — empty.
	var se []string = new(0) []string{}
	if len(slices.ScanString(se, "init", concat)) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
