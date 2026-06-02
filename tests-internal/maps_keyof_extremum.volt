package main
import "log"
import "maps"

// Positive test: maps.KeyOfMaxStringInt + KeyOfMinStringInt.

fun main() int {
	var pass int = 0

	// Clear max + min.
	var m map[string]int = new map[string]int
	m["alpha"] = 3
	m["bravo"] = 7
	m["charlie"] = 1
	m["delta"] = 5
	if maps.KeyOfMaxStringInt(m) == "bravo" { pass = pass + 1 }
	if maps.KeyOfMinStringInt(m) == "charlie" { pass = pass + 1 }

	// Single entry.
	var m1 map[string]int = new map[string]int
	m1["only"] = 42
	if maps.KeyOfMaxStringInt(m1) == "only" { pass = pass + 1 }
	if maps.KeyOfMinStringInt(m1) == "only" { pass = pass + 1 }

	// Empty.
	var m0 map[string]int = new map[string]int
	if maps.KeyOfMaxStringInt(m0) == "" { pass = pass + 1 }
	if maps.KeyOfMinStringInt(m0) == "" { pass = pass + 1 }

	// All negative values.
	var mn map[string]int = new map[string]int
	mn["a"] = -10
	mn["b"] = -3
	mn["c"] = -5
	if maps.KeyOfMaxStringInt(mn) == "b" { pass = pass + 1 }   // -3 is largest
	if maps.KeyOfMinStringInt(mn) == "a" { pass = pass + 1 }   // -10 is smallest

	// Two entries.
	var m2 map[string]int = new map[string]int
	m2["lo"] = 1
	m2["hi"] = 100
	if maps.KeyOfMaxStringInt(m2) == "hi" { pass = pass + 1 }
	if maps.KeyOfMinStringInt(m2) == "lo" { pass = pass + 1 }

	// Zero-valued entry coexisting with positives — zero is the min.
	var mz map[string]int = new map[string]int
	mz["zero"] = 0
	mz["pos"] = 5
	mz["bigger"] = 99
	if maps.KeyOfMaxStringInt(mz) == "bigger" { pass = pass + 1 }
	if maps.KeyOfMinStringInt(mz) == "zero" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
