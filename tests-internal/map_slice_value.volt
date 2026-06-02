package main
import "log"

// Positive test: `map[string][]int` and `map[string][]string` —
// slice-valued maps. Codegen now box-via-heap-ptr's the %slice
// value through the runtime's i64-only value slot.

fun main() int {
	var pass int = 0

	// Basic set + get on map[string][]int.
	var m map[string][]int = new map[string][]int
	var a []int = new(3) []int{10, 20, 30}
	m["alpha"] = a
	var b []int = new(2) []int{40, 50}
	m["beta"] = b

	if len(m) == 2 { pass = pass + 1 }
	if m["alpha"][0] == 10 { pass = pass + 1 }
	if m["alpha"][2] == 30 { pass = pass + 1 }
	if m["beta"][1] == 50 { pass = pass + 1 }

	// Missing key returns empty slice (len == 0).
	if len(m["gamma"]) == 0 { pass = pass + 1 }

	// Overwrite.
	var c []int = new(1) []int{99}
	m["alpha"] = c
	if m["alpha"][0] == 99 { pass = pass + 1 }
	if len(m["alpha"]) == 1 { pass = pass + 1 }

	// map[string][]string variant.
	var n map[string][]string = new map[string][]string
	var tags []string = new(2) []string{"red", "blue"}
	n["colors"] = tags

	if len(n) == 1 { pass = pass + 1 }
	if n["colors"][0] == "red" { pass = pass + 1 }
	if n["colors"][1] == "blue" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 10 { ret 42 }
	ret 0
}
