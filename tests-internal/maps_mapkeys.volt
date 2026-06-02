package main
import "log"
import "maps"
import "strings"

// Positive test: maps.MapKeysStringInt + maps.MapKeysStringString.

fun toUpper(s string) string { ret strings.ToUpper(s) }
fun toLower(s string) string { ret strings.ToLower(s) }
fun stripPrefix(s string) string { ret strings.TrimPrefix(s, "x-") }

fun main() int {
	var pass int = 0

	// MapKeysStringInt — basic uppercase keys.
	var m1 map[string]int = new map[string]int
	m1["apple"] = 1
	m1["banana"] = 2
	m1["cherry"] = 3
	var u map[string]int = maps.MapKeysStringInt(m1, toUpper)
	if u["APPLE"] == 1 { pass = pass + 1 }
	if u["BANANA"] == 2 { pass = pass + 1 }
	if u["CHERRY"] == 3 { pass = pass + 1 }
	if len(u) == 3 { pass = pass + 1 }

	// Original unchanged.
	if m1["apple"] == 1 { pass = pass + 1 }

	// MapKeysStringInt — empty.
	var emptyM map[string]int = new map[string]int
	var emptyU map[string]int = maps.MapKeysStringInt(emptyM, toUpper)
	if len(emptyU) == 0 { pass = pass + 1 }

	// MapKeysStringInt — strip-prefix normalizer.
	var m2 map[string]int = new map[string]int
	m2["x-foo"] = 10
	m2["x-bar"] = 20
	m2["baz"] = 30
	var stripped map[string]int = maps.MapKeysStringInt(m2, stripPrefix)
	if stripped["foo"] == 10 { pass = pass + 1 }
	if stripped["bar"] == 20 { pass = pass + 1 }
	if stripped["baz"] == 30 { pass = pass + 1 }
	if len(stripped) == 3 { pass = pass + 1 }

	// MapKeysStringString — basic lowercase.
	var m3 map[string]string = new map[string]string
	m3["NAME"] = "Alice"
	m3["AGE"] = "30"
	var lcKeys map[string]string = maps.MapKeysStringString(m3, toLower)
	if lcKeys["name"] == "Alice" { pass = pass + 1 }
	if lcKeys["age"] == "30" { pass = pass + 1 }
	if len(lcKeys) == 2 { pass = pass + 1 }

	// MapKeysStringString — values preserved literally.
	if lcKeys["name"] == m3["NAME"] { pass = pass + 1 }

	// MapKeysStringString — empty.
	var emptyM2 map[string]string = new map[string]string
	var emptyResult map[string]string = maps.MapKeysStringString(emptyM2, toLower)
	if len(emptyResult) == 0 { pass = pass + 1 }

	// MapKeysStringInt — identity (no-op rename).
	var same map[string]int = maps.MapKeysStringInt(m1, toUpper)
	if same["APPLE"] == m1["apple"] { pass = pass + 1 }

	// Single-entry map.
	var single map[string]string = new map[string]string
	single["foo"] = "bar"
	var renamed map[string]string = maps.MapKeysStringString(single, toUpper)
	if renamed["FOO"] == "bar" { pass = pass + 1 }
	if len(renamed) == 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
