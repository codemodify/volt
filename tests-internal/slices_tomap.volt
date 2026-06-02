package main
import "log"
import "slices"

// Positive test: slices.ToMapStringInt / ToMapStringString — zip
// two slices into a map. Later-key wins on duplicates; shorter
// prefix used on length mismatch.

fun main() int {
	var pass int = 0

	// Standard zip.
	var k1 []string = new(3) []string{"a", "b", "c"}
	var v1 []int = new(3) []int{1, 2, 3}
	var m1 map[string]int = slices.ToMapStringInt(k1, v1)
	if len(m1) == 3 { pass = pass + 1 }
	if m1["a"] == 1 { pass = pass + 1 }
	if m1["b"] == 2 { pass = pass + 1 }
	if m1["c"] == 3 { pass = pass + 1 }

	// Length mismatch: only shorter prefix used.
	var k2 []string = new(3) []string{"x", "y", "z"}
	var v2 []int = new(2) []int{10, 20}
	var m2 map[string]int = slices.ToMapStringInt(k2, v2)
	if len(m2) == 2 { pass = pass + 1 }
	if m2["x"] == 10 { pass = pass + 1 }
	if m2["y"] == 20 { pass = pass + 1 }

	// Duplicate keys: later wins.
	var k3 []string = new(3) []string{"a", "b", "a"}
	var v3 []int = new(3) []int{1, 2, 99}
	var m3 map[string]int = slices.ToMapStringInt(k3, v3)
	if len(m3) == 2 { pass = pass + 1 }
	if m3["a"] == 99 { pass = pass + 1 }

	// Empty inputs.
	var k4 []string = new(0) []string{}
	var v4 []int = new(0) []int{}
	var m4 map[string]int = slices.ToMapStringInt(k4, v4)
	if len(m4) == 0 { pass = pass + 1 }

	// ToMapStringString.
	var k5 []string = new(2) []string{"name", "city"}
	var v5 []string = new(2) []string{"Alice", "Paris"}
	var m5 map[string]string = slices.ToMapStringString(k5, v5)
	if len(m5) == 2 { pass = pass + 1 }
	if m5["name"] == "Alice" { pass = pass + 1 }
	if m5["city"] == "Paris" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
