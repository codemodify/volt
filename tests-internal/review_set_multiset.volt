package main
import "log"
import "slices"
import "maps"
import "strconv"

// Review test: exercise the in-scope set/multiset stdlib over sizes
// that cross the map grow threshold (16 buckets, grows at count>12),
// to validate key read-back after grow + after key-source drops.

fun isOdd(k string, v int) bool { ret v % 2 == 1 }
fun bump(v int) int { ret v + 100 }

fun main() int {
	var pass int = 0

	// --- IsSetInt: distinct vs dup, large (forces grow) ---
	var big []int = new(0) []int {}
	for i := 0; i < 40; i++ { big = append(big, i) }
	if slices.IsSetInt(big) { pass = pass + 1 }          // 1
	big = append(big, 7)
	if !slices.IsSetInt(big) { pass = pass + 1 }         // 2 (dup 7)

	// --- IntersectInt: distinct values in both, order of a ---
	var a1 []int = new(0) []int {}
	for i := 0; i < 30; i++ { a1 = append(a1, i) }
	var b1 []int = new(0) []int {}
	for i := 15; i < 50; i++ { b1 = append(b1, i) }
	var inter []int = slices.IntersectInt(a1, b1)        // expect 15..29 = 15 vals
	if len(inter) == 15 { pass = pass + 1 }              // 3
	if inter[0] == 15 { pass = pass + 1 }                // 4
	if inter[14] == 29 { pass = pass + 1 }               // 5

	// IntersectInt with dups in a (distinctness)
	var ad []int = new {1, 1, 2, 2, 3, 3}
	var bd []int = new {2, 3, 4}
	var id []int = slices.IntersectInt(ad, bd)
	if len(id) == 2 { pass = pass + 1 }                  // 6 (2,3 once)

	// --- UnionInt: distinct union, a-order then b-new ---
	var u []int = slices.UnionInt(a1, b1)                // 0..49 distinct = 50
	if len(u) == 50 { pass = pass + 1 }                  // 7
	if u[0] == 0 { pass = pass + 1 }                     // 8
	if u[49] == 49 { pass = pass + 1 }                   // 9
	var ua []int = new {1,1,1}
	var ub []int = new {1,2,2}
	var u2 []int = slices.UnionInt(ua, ub)
	if len(u2) == 2 { pass = pass + 1 }                  // 10

	// --- DifferenceInt: a minus b, distinct, a-order ---
	var d []int = slices.DifferenceInt(a1, b1)           // 0..14 = 15
	if len(d) == 15 { pass = pass + 1 }                  // 11
	if d[0] == 0 { pass = pass + 1 }                     // 12
	if d[14] == 14 { pass = pass + 1 }                   // 13
	var da []int = new {5,5,6,6}
	var db []int = new {6}
	var dd []int = slices.DifferenceInt(da, db)
	if len(dd) == 1 { pass = pass + 1 }                  // 14 (just 5)

	// --- SameMultisetInt: count map, +1/-1, grow + zero-check ---
	var ma []int = new(0) []int {}
	var mb []int = new(0) []int {}
	for i := 0; i < 30; i++ { ma = append(ma, i % 10) }   // each 0..9 thrice
	for i := 29; i >= 0; i-- { mb = append(mb, i % 10) }  // reversed, same multiset
	if slices.SameMultisetInt(ma, mb) { pass = pass + 1 } // 15
	var mc []int = new(0) []int {}
	for i := 0; i < 30; i++ { mc = append(mc, i % 10) }
	mc[0] = 99                                            // break one count
	if !slices.SameMultisetInt(ma, mc) { pass = pass + 1 }// 16

	// --- maps.MergeStringInt: b wins, grow (>12 keys) ---
	var pa map[string]int = new map[string]int
	var pb map[string]int = new map[string]int
	for i := 0; i < 20; i++ {
		var k string = strconv.Itoa(i)
		pa[k] = i
	}
	for i := 10; i < 30; i++ {
		var k string = strconv.Itoa(i)
		pb[k] = i * 1000
	}
	var mg map[string]int = maps.MergeStringInt(pa, pb)
	if len(mg) == 30 { pass = pass + 1 }                  // 17
	if mg[strconv.Itoa(5)] == 5 { pass = pass + 1 }       // 18 a-only
	if mg[strconv.Itoa(15)] == 15000 { pass = pass + 1 }  // 19 b wins
	if mg[strconv.Itoa(25)] == 25000 { pass = pass + 1 }  // 20 b-only

	// --- maps.FilterStringInt over grown map ---
	var fl map[string]int = maps.FilterStringInt(mg, isOdd)
	// odd values among mg: a-only odds 1,3,5,7,9 (5) + b odds? b values are i*1000 (even) -> 0; plus a-only evens excluded.
	// Actually mg keys 0..9 from pa (values 0..9): odd = 1,3,5,7,9 = 5
	// keys 10..29 from pb (values *1000 even) => none odd.
	if len(fl) == 5 { pass = pass + 1 }                   // 21

	// --- maps.InvertStringString ---
	var ss map[string]string = new {"a":"1","b":"2","c":"3"}
	var inv map[string]string = maps.InvertStringString(ss)
	if inv["1"] == "a" { pass = pass + 1 }                // 22
	if inv["3"] == "c" { pass = pass + 1 }                // 23

	// --- maps.MapKeysStringInt / MapValuesStringInt ---
	var mv map[string]int = maps.MapValuesStringInt(ss2int(), bump)
	if mv["x"] == 101 { pass = pass + 1 }                 // 24

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}

fun ss2int() map[string]int {
	var m map[string]int = new {"x":1, "y":2}
	ret m
}
