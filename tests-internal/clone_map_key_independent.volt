// Map clone key-independence (hardening): after the map-owns-keys fix,
// volt_map_clone must DEEP-COPY keys so cloning + dropping both copies
// doesn't double-free. Clone a map, delete a shared key from each side,
// insert more, and confirm both lookups stay correct + nothing crashes.
package main
import "log"
import "strconv"

fun main() int {
	var pass int = 0

	var m map[string]int = new map[string]int
	for i := 0; i < 20; i++ {
		var k string = strconv.Itoa(i)
		m[k] = i * 100
	}
	// Clone (deep key copy). Both maps must read independently.
	var n map[string]int = clone(m)
	if n[strconv.Itoa(5)] == 500 { pass = pass + 1 }
	if m[strconv.Itoa(5)] == 500 { pass = pass + 1 }

	// Delete a shared key from the CLONE only — original keeps it.
	delete(n, strconv.Itoa(5))
	if n[strconv.Itoa(5)] == 0 { pass = pass + 1 }     // gone in clone
	if m[strconv.Itoa(5)] == 500 { pass = pass + 1 }   // intact in original

	// Delete a different key from the ORIGINAL only.
	delete(m, strconv.Itoa(10))
	if m[strconv.Itoa(10)] == 0 { pass = pass + 1 }
	if n[strconv.Itoa(10)] == 1000 { pass = pass + 1 }

	// Insert fresh loop-local keys into both (exercise alloc churn that
	// would surface a double-free corruption).
	for i := 20; i < 40; i++ {
		var k string = strconv.Itoa(i)
		m[k] = i
		n[k] = i * 2
	}
	if m[strconv.Itoa(30)] == 30 { pass = pass + 1 }
	if n[strconv.Itoa(30)] == 60 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 8 { ret 42 }
	ret 0
}
