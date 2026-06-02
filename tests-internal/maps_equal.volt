package main
import "log"
import "maps"

// Positive test: maps.EqualStringInt / EqualStringString.

fun main() int {
	var pass int = 0

	// Equal: same entries, same order doesn't matter.
	var a1 map[string]int = new {"x": 1, "y": 2, "z": 3}
	var b1 map[string]int = new {"z": 3, "x": 1, "y": 2}
	if maps.EqualStringInt(a1, b1) { pass = pass + 1 }

	// Equal: different sizes.
	var a2 map[string]int = new {"x": 1, "y": 2}
	var b2 map[string]int = new {"x": 1, "y": 2, "z": 3}
	if !maps.EqualStringInt(a2, b2) { pass = pass + 1 }

	// Equal: same keys, different value.
	var a3 map[string]int = new {"x": 1, "y": 2}
	var b3 map[string]int = new {"x": 1, "y": 99}
	if !maps.EqualStringInt(a3, b3) { pass = pass + 1 }

	// Equal: same size, different key sets (a has "z", b has "w").
	var a4 map[string]int = new {"x": 1, "z": 3}
	var b4 map[string]int = new {"x": 1, "w": 3}
	if !maps.EqualStringInt(a4, b4) { pass = pass + 1 }

	// Equal: both empty.
	var a5 map[string]int = new map[string]int
	var b5 map[string]int = new map[string]int
	if maps.EqualStringInt(a5, b5) { pass = pass + 1 }

	// EqualStringString.
	var c1 map[string]string = new {"a": "apple", "b": "banana"}
	var d1 map[string]string = new {"a": "apple", "b": "banana"}
	if maps.EqualStringString(c1, d1) { pass = pass + 1 }

	// EqualStringString: different value.
	var c2 map[string]string = new {"a": "apple", "b": "banana"}
	var d2 map[string]string = new {"a": "apple", "b": "blueberry"}
	if !maps.EqualStringString(c2, d2) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 7 { ret 42 }
	ret 0
}
