package main
import "log"
import "maps"

fun main() int {
	var pass int = 0

	// Predeclare typed slots — volt's multi-return short-decl loses
	// element type info, so use explicit-var-then-multi-assign.
	var k []string = new(0) []string {}
	var v []int = new(0) []int {}

	// Basic: 4 keys with distinct values, top 2.
	var m1 map[string]int = new()
	m1["alpha"] = 10
	m1["bravo"] = 30
	m1["charlie"] = 20
	m1["delta"] = 5
	k, v = maps.TopNKeysStringInt(m1, 2)
	if len(k) == 2 { pass = pass + 1 }
	if len(v) == 2 { pass = pass + 1 }
	// Top: bravo(30), charlie(20)
	if k[0] == "bravo" { pass = pass + 1 }
	if v[0] == 30 { pass = pass + 1 }
	if k[1] == "charlie" { pass = pass + 1 }
	if v[1] == 20 { pass = pass + 1 }

	// n <= 0 → empty.
	k, v = maps.TopNKeysStringInt(m1, 0)
	if len(k) == 0 { pass = pass + 1 }
	if len(v) == 0 { pass = pass + 1 }

	k, v = maps.TopNKeysStringInt(m1, -3)
	if len(k) == 0 { pass = pass + 1 }
	if len(v) == 0 { pass = pass + 1 }

	// n > size → clamps to size.
	k, v = maps.TopNKeysStringInt(m1, 100)
	if len(k) == 4 { pass = pass + 1 }
	if len(v) == 4 { pass = pass + 1 }
	// Full descending order: bravo(30), charlie(20), alpha(10), delta(5)
	if v[0] == 30 { pass = pass + 1 }
	if v[1] == 20 { pass = pass + 1 }
	if v[2] == 10 { pass = pass + 1 }
	if v[3] == 5 { pass = pass + 1 }

	// Empty map → empty.
	var m4 map[string]int = new()
	k, v = maps.TopNKeysStringInt(m4, 5)
	if len(k) == 0 { pass = pass + 1 }
	if len(v) == 0 { pass = pass + 1 }

	// Single entry.
	var m5 map[string]int = new()
	m5["only"] = 42
	k, v = maps.TopNKeysStringInt(m5, 1)
	if len(k) == 1 { pass = pass + 1 }
	if k[0] == "only" { pass = pass + 1 }
	if v[0] == 42 { pass = pass + 1 }

	// All-same-value tie.
	var m6 map[string]int = new()
	m6["a"] = 7
	m6["b"] = 7
	m6["c"] = 7
	k, v = maps.TopNKeysStringInt(m6, 3)
	if len(k) == 3 { pass = pass + 1 }
	if v[0] == 7 { pass = pass + 1 }
	if v[1] == 7 { pass = pass + 1 }
	if v[2] == 7 { pass = pass + 1 }

	// Dashboard-pipeline use case.
	var m7 map[string]int = new()
	m7["foo"] = 1
	m7["bar"] = 100
	m7["baz"] = 50
	m7["qux"] = 25
	m7["quux"] = 0
	k, v = maps.TopNKeysStringInt(m7, 3)
	// Top 3 by value descending: bar(100), baz(50), qux(25)
	if k[0] == "bar" { pass = pass + 1 }
	if v[0] == 100 { pass = pass + 1 }
	if k[1] == "baz" { pass = pass + 1 }
	if v[1] == 50 { pass = pass + 1 }
	if k[2] == "qux" { pass = pass + 1 }
	if v[2] == 25 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 31 { ret 42 }
	ret 0
}
