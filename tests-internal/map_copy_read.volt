package main
import "log"

// Positive test: map reads no longer move the map when the value
// type is a Copy primitive (int, bool, byte, etc.). The checker
// previously moved the map on every read, forcing callers to use
// a single-read-then-cache pattern; now the natural multi-read
// pattern works.

fun main() int {
	var pass int = 0

	// map[string]int: multiple reads OK.
	var m map[string]int = new {"a": 1, "b": 2, "c": 3}
	if m["a"] == 1 { pass = pass + 1 }
	if m["b"] == 2 { pass = pass + 1 }
	if m["c"] == 3 { pass = pass + 1 }
	if m["a"] + m["b"] + m["c"] == 6 { pass = pass + 1 }

	// Loop with repeated map reads.
	var total int = 0
	var keys []string = new(3) []string{"a", "b", "c"}
	for i := 0; i < 3; i++ {
		total = total + m[keys[i]]
	}
	if total == 6 { pass = pass + 1 }

	// Mixed read + write on the same map.
	m["d"] = m["a"] + m["b"]
	if m["d"] == 3 { pass = pass + 1 }

	// map[string]bool also OK.
	var seen map[string]bool = new map[string]bool
	seen["x"] = true
	if seen["x"] { pass = pass + 1 }
	if !seen["y"] { pass = pass + 1 }

	// map[string][]int (slice-valued) still moves on read — that
	// path's contract is unchanged. Verify the read works in the
	// single-bind pattern.
	var ms map[string][]int = new map[string][]int
	var v []int = new(2) []int{10, 20}
	ms["k"] = v
	var got []int = ms["k"]
	if got[1] == 20 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 9 { ret 42 }
	ret 0
}
