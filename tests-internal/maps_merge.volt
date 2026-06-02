package main
import "log"
import "maps"

// Positive test: maps.MergeStringInt / MergeStringString. Produces
// a new map with all entries from a followed by all from b; b wins
// on collisions.

fun main() int {
	var pass int = 0

	// Disjoint keys: result has both sets.
	var a1 map[string]int = new {"x": 1, "y": 2}
	var b1 map[string]int = new {"z": 3, "w": 4}
	var r1 map[string]int = maps.MergeStringInt(a1, b1)
	if len(r1) == 4 { pass = pass + 1 }
	if r1["x"] == 1 { pass = pass + 1 }
	if r1["z"] == 3 { pass = pass + 1 }

	// Collision: b wins.
	var a2 map[string]int = new {"x": 1, "y": 2}
	var b2 map[string]int = new {"x": 99, "z": 3}
	var r2 map[string]int = maps.MergeStringInt(a2, b2)
	if len(r2) == 3 { pass = pass + 1 }
	if r2["x"] == 99 { pass = pass + 1 }
	if r2["y"] == 2 { pass = pass + 1 }
	if r2["z"] == 3 { pass = pass + 1 }

	// Empty a, non-empty b.
	var a3 map[string]int = new map[string]int
	var b3 map[string]int = new {"foo": 42}
	var r3 map[string]int = maps.MergeStringInt(a3, b3)
	if len(r3) == 1 { pass = pass + 1 }
	if r3["foo"] == 42 { pass = pass + 1 }

	// Both empty.
	var a4 map[string]int = new map[string]int
	var b4 map[string]int = new map[string]int
	var r4 map[string]int = maps.MergeStringInt(a4, b4)
	if len(r4) == 0 { pass = pass + 1 }

	// MergeStringString.
	var sa map[string]string = new {"name": "Alice", "role": "admin"}
	var sb map[string]string = new {"role": "user", "city": "Paris"}
	var sr map[string]string = maps.MergeStringString(sa, sb)
	if len(sr) == 3 { pass = pass + 1 }
	if sr["name"] == "Alice" { pass = pass + 1 }
	if sr["role"] == "user" { pass = pass + 1 }
	if sr["city"] == "Paris" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
