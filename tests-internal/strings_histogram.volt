package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Basic 3-row dashboard. max count is 10 → bar 10 wide, "alpha" 4 → 4
	// chars. Labels: alpha(5), bravo(5), charlie(7). labelWidth = 7.
	var labels1 []string = new(3) []string {"alpha", "bravo", "charlie"}
	var counts1 []int = new(3) []int {4, 7, 10}
	var h1 string = strings.AsciiHistogram(labels1, counts1, 10, 35, 46)
	// Expected:
	// "alpha   | ####......\nbravo   | #######...\ncharlie | ##########"
	var want1 string = "alpha   | ####......\nbravo   | #######...\ncharlie | ##########"
	if h1 == want1 { pass = pass + 1 }

	// Single row.
	var labels2 []string = new(1) []string {"only"}
	var counts2 []int = new(1) []int {5}
	var h2 string = strings.AsciiHistogram(labels2, counts2, 5, 35, 46)
	if h2 == "only | #####" { pass = pass + 1 }

	// Empty input.
	var labels3 []string = new(0) []string {}
	var counts3 []int = new(0) []int {}
	var h3 string = strings.AsciiHistogram(labels3, counts3, 10, 35, 46)
	if h3 == "" { pass = pass + 1 }

	// Mismatched lengths.
	var labels4 []string = new(2) []string {"a", "b"}
	var counts4 []int = new(3) []int {1, 2, 3}
	var h4 string = strings.AsciiHistogram(labels4, counts4, 5, 35, 46)
	if h4 == "" { pass = pass + 1 }

	// All zero counts → all empty bars.
	var labels5 []string = new(2) []string {"zero1", "zero2"}
	var counts5 []int = new(2) []int {0, 0}
	var h5 string = strings.AsciiHistogram(labels5, counts5, 4, 35, 46)
	// labelWidth=5, both bars empty
	if h5 == "zero1 | ....\nzero2 | ...." { pass = pass + 1 }

	// Negative count clamps to 0; max is still 5.
	var labels6 []string = new(2) []string {"neg", "pos"}
	var counts6 []int = new(2) []int {-3, 5}
	var h6 string = strings.AsciiHistogram(labels6, counts6, 5, 35, 46)
	// labelWidth=3, max=5, scale to 5: neg → 0/5, pos → 5/5
	if h6 == "neg | .....\npos | #####" { pass = pass + 1 }

	// Different fill / empty.
	var labels7 []string = new(2) []string {"x", "y"}
	var counts7 []int = new(2) []int {1, 2}
	var h7 string = strings.AsciiHistogram(labels7, counts7, 4, 42, 32)
	// max=2, x: 1*4/2=2 → **  , y: 2*4/2=4 → ****
	if h7 == "x | **  \ny | ****" { pass = pass + 1 }

	// Single tall bar dominates the scale.
	var labels8 []string = new(3) []string {"a", "b", "c"}
	var counts8 []int = new(3) []int {1, 1, 100}
	var h8 string = strings.AsciiHistogram(labels8, counts8, 10, 35, 46)
	// max=100, a: 1*10/100=0, b: 0, c: 10
	if h8 == "a | ..........\nb | ..........\nc | ##########" { pass = pass + 1 }

	// Verify no trailing newline.
	var labels9 []string = new(2) []string {"x", "y"}
	var counts9 []int = new(2) []int {1, 1}
	var h9 string = strings.AsciiHistogram(labels9, counts9, 2, 35, 46)
	var lastChar byte = h9[len(h9)-1]
	if lastChar != 10 { pass = pass + 1 }

	// Counts of all same value → all full bars.
	var labelsA []string = new(3) []string {"a", "b", "c"}
	var countsA []int = new(3) []int {7, 7, 7}
	var hA string = strings.AsciiHistogram(labelsA, countsA, 5, 35, 46)
	if hA == "a | #####\nb | #####\nc | #####" { pass = pass + 1 }

	// barWidth=0 yields blank bars.
	var labelsB []string = new(2) []string {"a", "b"}
	var countsB []int = new(2) []int {3, 5}
	var hB string = strings.AsciiHistogram(labelsB, countsB, 0, 35, 46)
	if hB == "a | \nb | " { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 11 { ret 42 }
	ret 0
}
