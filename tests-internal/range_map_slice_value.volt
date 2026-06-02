package main
import "log"
import "slices"

// Positive test: `for k, v := range m` over a slice-valued map
// (`map[K][]T`) — companion to LANG.9 (slice-valued map set/get).
// The range binding `v` must materialize as a real `%slice`, not as
// the raw i64 storage slot.

fun main() int {
	var pass int = 0

	// Build map[string][]int via GroupBy and iterate.
	var src []int = new(6) []int{1, 2, 3, 4, 5, 6}
	var grouped map[string][]int = slices.GroupByStringInt(src, parity)

	var seenEven bool = false
	var seenOdd bool = false
	var evenTotal int = 0
	var oddTotal int = 0
	for k, v := range grouped {
		var vn int = len(v)
		var sum int = 0
		for i := 0; i < vn; i++ {
			sum = sum + v[i]
		}
		if k == "even" {
			seenEven = true
			evenTotal = sum
		}
		if k == "odd" {
			seenOdd = true
			oddTotal = sum
		}
	}
	if seenEven { pass = pass + 1 }
	if seenOdd { pass = pass + 1 }
	if evenTotal == 12 { pass = pass + 1 }   // 2 + 4 + 6
	if oddTotal == 9 { pass = pass + 1 }     // 1 + 3 + 5

	// Direct map[string][]string range.
	var m map[string][]string = new map[string][]string
	var tags1 []string = new(2) []string{"red", "blue"}
	m["colors"] = tags1
	var tags2 []string = new(2) []string{"apple", "orange"}
	m["fruits"] = tags2

	var totalLen int = 0
	for k, v := range m {
		totalLen = totalLen + len(v) + len(k)
	}
	// "colors".len + 2 + "fruits".len + 2 = 6 + 2 + 6 + 2 = 16
	if totalLen == 16 { pass = pass + 1 }

	log.Println("pass=%d evenTotal=%d", pass, evenTotal)
	if pass == 5 { ret 42 }
	ret 0
}

fun parity(v int) string {
	if (v % 2) == 0 { ret "even" }
	ret "odd"
}
