package main
import "log"
import "slices"
import "strconv"
import "bytes"

// Positive test: slices.GroupByStringInt / GroupByStringString —
// LINQ-style group-by-computed-key.

fun parity(v int) string {
	if (v % 2) == 0 { ret "even" }
	ret "odd"
}

fun firstChar(s string) string {
	if len(s) == 0 { ret "" }
	var b *bytes.Builder = bytes.NewBuilder()
	b.WriteByte(s[0])
	ret b.String()
}

fun lenKey(v int) string {
	ret strconv.Itoa(v % 3)
}

fun main() int {
	var pass int = 0

	// Group ints by parity.
	var s1 []int = new(6) []int{1, 2, 3, 4, 5, 6}
	var g1 map[string][]int = slices.GroupByStringInt(s1, parity)
	if len(g1) == 2 { pass = pass + 1 }
	if len(g1["odd"]) == 3 { pass = pass + 1 }
	if len(g1["even"]) == 3 { pass = pass + 1 }
	if g1["odd"][0] == 1 { pass = pass + 1 }
	if g1["even"][2] == 6 { pass = pass + 1 }

	// Group ints by `v % 3` (3 buckets: 0, 1, 2).
	var s2 []int = new(7) []int{0, 1, 2, 3, 4, 5, 6}
	var g2 map[string][]int = slices.GroupByStringInt(s2, lenKey)
	if len(g2) == 3 { pass = pass + 1 }
	if len(g2["0"]) == 3 { pass = pass + 1 }   // 0, 3, 6
	if len(g2["1"]) == 2 { pass = pass + 1 }   // 1, 4
	if len(g2["2"]) == 2 { pass = pass + 1 }   // 2, 5

	// Empty input.
	var s3 []int = new(0) []int{}
	var g3 map[string][]int = slices.GroupByStringInt(s3, parity)
	if len(g3) == 0 { pass = pass + 1 }

	// GroupByStringString by first char.
	var s4 []string = new(5) []string{"apple", "ant", "banana", "berry", "cherry"}
	var g4 map[string][]string = slices.GroupByStringString(s4, firstChar)
	if len(g4) == 3 { pass = pass + 1 }
	if len(g4["a"]) == 2 { pass = pass + 1 }
	if len(g4["b"]) == 2 { pass = pass + 1 }
	if len(g4["c"]) == 1 { pass = pass + 1 }
	if g4["a"][0] == "apple" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
