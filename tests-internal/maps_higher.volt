package main
import "log"
import "maps"

// Positive test: maps.FilterStringInt / FilterStringString /
// MapValuesStringInt — higher-order map helpers.

fun keepPos(k string, v int) bool { ret v > 0 }
fun keepShortKey(k string, v int) bool { ret len(k) <= 2 }
fun keepNonEmpty(k string, v string) bool { ret len(v) > 0 }
fun double(v int) int { ret v * 2 }
fun negate(v int) int { ret -v }

fun main() int {
	var pass int = 0

	// FilterStringInt: keep positive values.
	var m1 map[string]int = new {"x": 5, "y": -3, "z": 10, "w": 0}
	var r1 map[string]int = maps.FilterStringInt(m1, keepPos)
	if len(r1) == 2 { pass = pass + 1 }
	if r1["x"] == 5 { pass = pass + 1 }
	if r1["z"] == 10 { pass = pass + 1 }

	// FilterStringInt: keep short keys.
	var m2 map[string]int = new {"a": 1, "bb": 2, "ccc": 3, "dddd": 4}
	var r2 map[string]int = maps.FilterStringInt(m2, keepShortKey)
	if len(r2) == 2 { pass = pass + 1 }
	if r2["a"] == 1 { pass = pass + 1 }
	if r2["bb"] == 2 { pass = pass + 1 }

	// Filter to empty result.
	var m3 map[string]int = new {"a": -1, "b": -2}
	var r3 map[string]int = maps.FilterStringInt(m3, keepPos)
	if len(r3) == 0 { pass = pass + 1 }

	// FilterStringString.
	var ms map[string]string = new {"a": "apple", "b": "", "c": "carrot"}
	var rs map[string]string = maps.FilterStringString(ms, keepNonEmpty)
	if len(rs) == 2 { pass = pass + 1 }
	if rs["a"] == "apple" { pass = pass + 1 }
	if rs["c"] == "carrot" { pass = pass + 1 }

	// MapValuesStringInt: double each.
	var m4 map[string]int = new {"x": 1, "y": 2, "z": 3}
	var r4 map[string]int = maps.MapValuesStringInt(m4, double)
	if len(r4) == 3 { pass = pass + 1 }
	if r4["x"] == 2 { pass = pass + 1 }
	if r4["y"] == 4 { pass = pass + 1 }
	if r4["z"] == 6 { pass = pass + 1 }

	// MapValuesStringInt: negate.
	var m5 map[string]int = new {"a": 5, "b": -3}
	var r5 map[string]int = maps.MapValuesStringInt(m5, negate)
	if r5["a"] == -5 { pass = pass + 1 }
	if r5["b"] == 3 { pass = pass + 1 }

	// Empty map → empty result.
	var m6 map[string]int = new map[string]int
	var r6 map[string]int = maps.MapValuesStringInt(m6, double)
	if len(r6) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
