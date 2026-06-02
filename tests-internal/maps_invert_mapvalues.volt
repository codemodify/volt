package main
import "log"
import "maps"
import "strings"

// Positive test: maps.InvertStringString + maps.MapValuesStringString.

fun toUpper(s string) string { ret strings.ToUpper(s) }
fun trimSpace(s string) string { ret strings.TrimSpace(s) }

fun main() int {
	var pass int = 0

	// InvertStringString — basic.
	var m1 map[string]string = new map[string]string
	m1["apple"] = "red"
	m1["banana"] = "yellow"
	m1["grape"] = "purple"

	var inv map[string]string = maps.InvertStringString(m1)
	if inv["red"] == "apple" { pass = pass + 1 }
	if inv["yellow"] == "banana" { pass = pass + 1 }
	if inv["purple"] == "grape" { pass = pass + 1 }
	if len(inv) == 3 { pass = pass + 1 }

	// InvertStringString — empty.
	var emptyM map[string]string = new map[string]string
	var emptyInv map[string]string = maps.InvertStringString(emptyM)
	if len(emptyInv) == 0 { pass = pass + 1 }

	// InvertStringString — single entry.
	var single map[string]string = new map[string]string
	single["x"] = "y"
	var singleInv map[string]string = maps.InvertStringString(single)
	if singleInv["y"] == "x" { pass = pass + 1 }
	if len(singleInv) == 1 { pass = pass + 1 }

	// Double invert returns the original (when values are unique).
	var double map[string]string = maps.InvertStringString(maps.InvertStringString(m1))
	if double["apple"] == "red" { pass = pass + 1 }
	if double["banana"] == "yellow" { pass = pass + 1 }
	if double["grape"] == "purple" { pass = pass + 1 }

	// MapValuesStringString — uppercase each value.
	var lc map[string]string = new map[string]string
	lc["a"] = "hello"
	lc["b"] = "world"
	var uc map[string]string = maps.MapValuesStringString(lc, toUpper)
	if uc["a"] == "HELLO" { pass = pass + 1 }
	if uc["b"] == "WORLD" { pass = pass + 1 }
	if len(uc) == 2 { pass = pass + 1 }

	// Original map unchanged.
	if lc["a"] == "hello" { pass = pass + 1 }

	// MapValuesStringString — trim each value.
	var padded map[string]string = new map[string]string
	padded["x"] = "  spaced  "
	padded["y"] = "\ttabbed\n"
	var trimmed map[string]string = maps.MapValuesStringString(padded, trimSpace)
	if trimmed["x"] == "spaced" { pass = pass + 1 }
	if trimmed["y"] == "tabbed" { pass = pass + 1 }

	// MapValuesStringString — empty input.
	var emptyMV map[string]string = maps.MapValuesStringString(emptyM, toUpper)
	if len(emptyMV) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
