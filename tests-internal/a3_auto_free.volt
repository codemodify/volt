// A3 auto-free smoke test. Allocates many slices and maps in a tight
// loop. With auto-free at scope exit, the same size-class freelist
// recycles the memory so total heap growth is bounded. Without
// auto-free the program would still pass (the bump allocator backing
// memory just grows) — this test confirms it runs without crashing,
// proving the volt_slice_free / volt_map_free calls are correct.
package main
import "log"

fun makeAndIndex(n int) int {
	var s []int = new(n) []int {}
	for i := 0; i < n; i++ {
		s[i] = i * 2
	}
	var sum int = 0
	for i := 0; i < n; i++ {
		sum = sum + s[i]
	}
	ret sum
	// s drops here — buffer is freed by volt_slice_free.
}

fun mapStuff(n int) int {
	var m map[string]int = new()
	m["a"] = 1
	m["b"] = 2
	m["c"] = 3
	var total int = 0
	for i := 0; i < n; i++ {
		// Look up each key — index reads don't transfer ownership.
		total = total + m["a"] + m["b"] + m["c"]
	}
	ret total
	// m drops here — volt_map_free walks entries+buckets+header.
}

fun main() int {
	var s int = 0
	for i := 0; i < 200; i++ {
		s = s + makeAndIndex(50)
	}
	// makeAndIndex(50) returns sum of 0..98 step 2 = 2*(0+1+...+49) = 2*1225 = 2450
	// Times 200 = 490000

	var t int = 0
	for i := 0; i < 50; i++ {
		t = t + mapStuff(3)
	}
	// mapStuff(3) returns 3 * (1+2+3) = 18; times 50 = 900

	log.Println("s=%d t=%d", s, t)
	if s == 490000 {
		if t == 900 { ret 42 }
	}
	ret 0
}
