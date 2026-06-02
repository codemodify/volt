package main
import "log"
import "maps"

fun valHasPrefixHttp(k string, v string) bool {
	if len(v) < 4 { ret false }
	if v[0] == 104 {       // 'h'
		if v[1] == 116 {   // 't'
			if v[2] == 116 {
				if v[3] == 112 {   // 'p'
					ret true
				}
			}
		}
	}
	ret false
}

fun valIsEmpty(k string, v string) bool {
	if len(v) == 0 { ret true }
	ret false
}

fun keyStartsWithA(k string, v string) bool {
	if len(k) == 0 { ret false }
	if k[0] == 97 { ret true }
	ret false
}

fun main() int {
	var pass int = 0

	// AnyStringString — at least one match.
	var m1 map[string]string = new map[string]string
	m1["home"] = "https://example.com"
	m1["title"] = "Hello"
	if maps.AnyStringString(m1, valHasPrefixHttp) { pass = pass + 1 }

	// AnyStringString — no match.
	var m2 map[string]string = new map[string]string
	m2["a"] = "hello"
	m2["b"] = "world"
	if !maps.AnyStringString(m2, valHasPrefixHttp) { pass = pass + 1 }

	// AnyStringString — empty map.
	var m3 map[string]string = new map[string]string
	if !maps.AnyStringString(m3, valHasPrefixHttp) { pass = pass + 1 }

	// AllStringString — all match.
	var m4 map[string]string = new map[string]string
	m4["home"] = "https://example.com"
	m4["docs"] = "https://docs.example.com"
	if maps.AllStringString(m4, valHasPrefixHttp) { pass = pass + 1 }

	// AllStringString — one fails.
	var m5 map[string]string = new map[string]string
	m5["home"] = "https://example.com"
	m5["title"] = "Hello"
	if !maps.AllStringString(m5, valHasPrefixHttp) { pass = pass + 1 }

	// AllStringString — empty vacuous true.
	if maps.AllStringString(m3, valHasPrefixHttp) { pass = pass + 1 }

	// CountStringString — basic.
	var m6 map[string]string = new map[string]string
	m6["a"] = "x"
	m6["b"] = ""
	m6["c"] = ""
	m6["d"] = "y"
	if maps.CountStringString(m6, valIsEmpty) == 2 { pass = pass + 1 }
	if maps.CountStringString(m3, valIsEmpty) == 0 { pass = pass + 1 }

	// Key-based predicates.
	var m7 map[string]string = new map[string]string
	m7["alpha"] = "1"
	m7["apple"] = "2"
	m7["banana"] = "3"
	if maps.AnyStringString(m7, keyStartsWithA) { pass = pass + 1 }
	if !maps.AllStringString(m7, keyStartsWithA) { pass = pass + 1 }
	if maps.CountStringString(m7, keyStartsWithA) == 2 { pass = pass + 1 }

	// All-keys-start-with-A → AllStringString true.
	var m8 map[string]string = new map[string]string
	m8["apple"] = "1"
	m8["apricot"] = "2"
	if maps.AllStringString(m8, keyStartsWithA) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
