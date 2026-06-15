// Param-disposition (S3 level 3): a container passed to an audited
// BORROW-only stdlib fn (it reads + retains nothing) is NOT marked moved, so
// the caller frees it at scope end. Here the map m is built, passed to
// maps.ValuesStringInt (which borrows it), then both m AND the returned slice
// are freed at scope exit — must not double-free. Looped so a double-free
// would crash; VmPeak measured ~flat separately (424MB -> 30MB).
package main

import "maps"

fun rt() int {
	var m map[string]int = new map[string]int
	m["aa"] = 1
	m["bb"] = 2
	m["cc"] = 3
	var vs []int = maps.ValuesStringInt(m) // borrows m; returns fresh []int
	var s int = 0
	for i := 0; i < len(vs); i++ {
		var v int = vs[i]
		s = s + v
	}
	ret s // scope: m freed (param-borrow) + vs backing freed (S3). no double-free.
}

fun main() int {
	var acc int = 0
	for i := 0; i < 100000; i++ {
		acc = acc + rt()
	}
	if acc == 600000 {
		ret 42
	}
	ret 0
}
