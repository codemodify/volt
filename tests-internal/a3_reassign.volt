// A3 reassignment cleanup: when a slice/map/string var is rebound,
// the OLD heap value should be freed before the new value is stored
// — preventing leaks across rebinds in long-running programs.
package main
import "log"

fun main() int {
	// 1. Slice reassignment: each iteration assigns a fresh new()
	// slice. Without reassignment cleanup, the prior allocation would
	// leak. 10000 iters × 100 ints = ~8MB peak if leaked; with cleanup
	// we stay within freelist recycling.
	var s []int = new(10) []int {}
	for i := 0; i < 10000; i++ {
		s = new(100) []int {}
		s[0] = i
	}

	// 2. Map reassignment: same idea — freshly bound each iter.
	var m map[string]int = new map[string]int
	for i := 0; i < 5000; i++ {
		m = new map[string]int
		m["k"] = i
	}

	// 3. String reassignment via concat (heap producer).
	var prefix string = "hello-"
	var suffix string = "world"
	var t string = prefix + suffix  // heap allocation
	for i := 0; i < 5000; i++ {
		t = prefix + suffix  // old heap value gets freed, fresh allocation
	}
	if len(t) != 11 { ret 1 }

	// 4. String reassignment to a LITERAL: old heap value must be
	// freed; new literal must NOT be queued for free at scope exit.
	var u string = "ab" + "cd"  // heap
	u = "literal-not-heap"      // literal — old "abcd" freed; drop removed
	if u != "literal-not-heap" { ret 2 }
	if len(u) != 16 { ret 3 }

	// 5. Multiple slice rebinds within the same scope.
	var w []int = new(5) []int {}
	w[0] = 1
	w = new(10) []int {}  // free old(5), register new(10)
	w[5] = 99
	w = new(20) []int {}  // free old(10), register new(20)
	w[19] = 42
	if w[19] != 42 { ret 4 }

	log.Println("ok")
	ret 42
}
