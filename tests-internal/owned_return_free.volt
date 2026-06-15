// S3 first cut: a slice returned by an audited stdlib OWNED-RETURN function
// (strings.Fields/Split, maps.Keys/Values) is a fresh caller-owned slice, so
// its BACKING is freed at scope exit. Safety: only the backing is freed (never
// the elements — a return's elements may alias the callee's inputs, e.g.
// maps.Keys aliases the map's key buffers), so freeing the result AND the map
// must not double-free. Looped so a double-free would crash.
package main

import "strings"
import "maps"

fun viaFields() int {
	var ws []string = strings.Fields("the quick brown fox")
	ret len(ws) // backing freed at scope end
}

fun viaKeys() int {
	var m map[string]int = new map[string]int
	m["aa"] = 1
	m["bb"] = 2
	var ks []string = maps.KeysStringInt(m)
	ret len(ks) // ks backing freed AND m freed (its key copies) — no double-free
}

fun main() int {
	var acc int = 0
	for i := 0; i < 100000; i++ {
		acc = acc + viaFields() + viaKeys()
	}
	// (4 + 2) * 100000 = 600000
	if acc == 600000 {
		ret 42
	}
	ret 0
}
