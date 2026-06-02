package main
import "log"
import "maps"

fun valGt10(k string, v int) bool { ret v > 10 }
fun valIsZero(k string, v int) bool { ret v == 0 }
fun keyStartsWithA(k string, v int) bool {
	if len(k) == 0 { ret false }
	if k[0] == 97 { ret true }
	ret false
}
fun valIsPositive(k string, v int) bool { ret v > 0 }

fun main() int {
	var pass int = 0

	// AnyStringInt — at least one match.
	var m1 map[string]int = new map[string]int
	m1["a"] = 5
	m1["b"] = 100
	m1["c"] = 3
	if maps.AnyStringInt(m1, valGt10) { pass = pass + 1 }

	// AnyStringInt — no match.
	var m2 map[string]int = new map[string]int
	m2["a"] = 1
	m2["b"] = 2
	m2["c"] = 3
	if !maps.AnyStringInt(m2, valGt10) { pass = pass + 1 }

	// AnyStringInt — empty map.
	var m3 map[string]int = new map[string]int
	if !maps.AnyStringInt(m3, valGt10) { pass = pass + 1 }

	// AllStringInt — every entry matches.
	var m4 map[string]int = new map[string]int
	m4["a"] = 50
	m4["b"] = 100
	m4["c"] = 25
	if maps.AllStringInt(m4, valGt10) { pass = pass + 1 }

	// AllStringInt — one fails.
	var m5 map[string]int = new map[string]int
	m5["a"] = 50
	m5["b"] = 5    // fails > 10
	m5["c"] = 25
	if !maps.AllStringInt(m5, valGt10) { pass = pass + 1 }

	// AllStringInt — empty map → true (vacuous).
	var m6 map[string]int = new map[string]int
	if maps.AllStringInt(m6, valGt10) { pass = pass + 1 }

	// CountStringInt — basic counts.
	var m7 map[string]int = new map[string]int
	m7["a"] = 1
	m7["b"] = 0
	m7["c"] = 0
	m7["d"] = 5
	if maps.CountStringInt(m7, valIsZero) == 2 { pass = pass + 1 }
	if maps.CountStringInt(m7, valIsPositive) == 2 { pass = pass + 1 }
	if maps.CountStringInt(m7, valGt10) == 0 { pass = pass + 1 }

	// CountStringInt — empty.
	if maps.CountStringInt(m3, valIsZero) == 0 { pass = pass + 1 }

	// AnyStringInt / AllStringInt — key-based predicates.
	var m8 map[string]int = new map[string]int
	m8["alpha"] = 1
	m8["apple"] = 2
	m8["banana"] = 3
	if maps.AnyStringInt(m8, keyStartsWithA) { pass = pass + 1 }
	if !maps.AllStringInt(m8, keyStartsWithA) { pass = pass + 1 }
	if maps.CountStringInt(m8, keyStartsWithA) == 2 { pass = pass + 1 }

	// All-keys-start-with-A → AllStringInt true.
	var m9 map[string]int = new map[string]int
	m9["apple"] = 1
	m9["apricot"] = 2
	if maps.AllStringInt(m9, keyStartsWithA) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
