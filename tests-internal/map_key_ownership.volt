// Map key-ownership regression (hardening): the map COPIES caller keys
// on insert, so loop-local heap key strings (freed by A3 at scope end)
// can't corrupt stored keys via freelist reuse. Covers insert,
// read-back across iterations, overwrite, delete, and grow/rehash
// (MAP_INIT_BUCKETS=16 grows past ~12 entries).
package main
import "log"
import "strconv"

fun main() int {
	var pass int = 0

	// --- count map with loop-local keys (the original repro) ---
	var src []int = new(6) []int {1, 2, 2, 3, 3, 3}
	var counts map[string]int = new map[string]int
	for i := 0; i < 6; i++ {
		var k string = strconv.Itoa(src[i])   // fresh heap string each iter
		counts[k] = counts[k] + 1
	}
	if counts[strconv.Itoa(1)] == 1 { pass = pass + 1 }
	if counts[strconv.Itoa(2)] == 2 { pass = pass + 1 }
	if counts[strconv.Itoa(3)] == 3 { pass = pass + 1 }

	// --- overwrite: same key set twice updates value, no corruption ---
	var ov map[string]int = new map[string]int
	for i := 0; i < 5; i++ {
		var k string = strconv.Itoa(7)
		ov[k] = i
	}
	if ov[strconv.Itoa(7)] == 4 { pass = pass + 1 }   // last write wins

	// --- delete then re-read ---
	var dm map[string]int = new map[string]int
	dm["alpha"] = 10
	dm["beta"] = 20
	delete(dm, "alpha")
	if dm["alpha"] == 0 { pass = pass + 1 }   // gone → zero value
	if dm["beta"] == 20 { pass = pass + 1 }   // survivor intact

	// --- grow/rehash: insert 50 distinct loop-local keys, read all back ---
	var big map[string]int = new map[string]int
	for i := 0; i < 50; i++ {
		var k string = strconv.Itoa(i * 13 + 1)   // distinct heap keys
		big[k] = i
	}
	var ok bool = true
	for i := 0; i < 50; i++ {
		var k string = strconv.Itoa(i * 13 + 1)
		if big[k] != i { ok = false }
	}
	if ok { pass = pass + 1 }

	// --- empty-string key is a valid, owned key ---
	var em map[string]int = new map[string]int
	em[""] = 99
	if em[""] == 99 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 8 { ret 42 }
	ret 0
}
