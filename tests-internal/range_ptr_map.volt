package main

// Positive test: range over `map[K]*T` exposes `v` as a ptr typed
// to the declared `*T`, not the raw i64 storage slot. So `v.x`
// field-access works directly via the FEAT.7 auto-deref machinery.

type Box struct {
	x int
}

fun main() int {
	var m map[string]*Box = new {"a": new Box{x: 7}, "b": new Box{x: 35}}
	var total int = 0
	for _, v := range m {
		total = total + v.x
	}
	if total != 42 { ret 1 }
	ret 42
}
