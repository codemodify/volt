// Map string-VALUE ownership (hardening). The map owns + frees its
// boxed %string values; map-get DEEP-COPIES so the map stays sole owner
// of its backing. Uses HEAP string values (strings.Repeat / concat) —
// NOT .rodata literals — since literal backings no-op in volt_str_free
// and would hide the double-free/UAF this guards against.
package main
import "log"
import "strings"
import "strconv"

fun main() int {
	var pass int = 0

	// (1) Read a heap value out, store into another map, drop both:
	// no double-free (the get deep-copies so backings are independent).
	{
		var m map[string]string = new map[string]string
		var n map[string]string = new map[string]string
		m["a"] = strings.Repeat("x", 5000)
		var s string = m["a"]
		n["x"] = s
		if len(n["x"]) == 5000 { pass = pass + 1 }
	}

	// (2) Read-escape into a slice, then overwrite the key: the escaped
	// copy must stay valid (no use-after-free).
	{
		var m map[string]string = new map[string]string
		m["k"] = "AAAA" + strconv.Itoa(1111)
		var acc []string = new(0) []string {}
		acc = append(acc, m["k"])
		m["k"] = "overwritten-value-here"
		var poison string = strings.Repeat("B", 64)
		if len(poison) != 64 { ret 90 }
		if acc[0] == "AAAA1111" { pass = pass + 1 }
	}

	// (3) Clone independence: heap values, mutate each side, both intact.
	{
		var m map[string]string = new map[string]string
		var i int = 0
		for i < 10 { var k string = strconv.Itoa(i); m[k] = "val-" + strconv.Itoa(i * 5); i = i + 1 }
		var c map[string]string = clone(m)
		c["3"] = "CHANGED"
		if m[strconv.Itoa(3)] == "val-15" { pass = pass + 1 }
		if c[strconv.Itoa(3)] == "CHANGED" { pass = pass + 1 }
		delete(m, "7")
		if m["7"] == "" { pass = pass + 1 }
		if c[strconv.Itoa(7)] == "val-35" { pass = pass + 1 }
	}

	// (4) Overwrite churn: repeatedly overwrite a heap value (old freed each time).
	{
		var m map[string]string = new map[string]string
		var i int = 0
		for i < 50 { m["key"] = "payload-" + strconv.Itoa(i); i = i + 1 }
		if m["key"] == "payload-49" { pass = pass + 1 }
	}

	log.Println("pass=%d", pass)
	if pass == 7 { ret 42 }
	ret 0
}
