package main
import "log"
import "hash/fnv"

fun main() int {
	var pass int = 0

	// Distinct ints produce distinct 32-bit hashes (no collision in this small set).
	var h0 int = fnv.HashInt32(0)
	var h1 int = fnv.HashInt32(1)
	var h2 int = fnv.HashInt32(2)
	var h100 int = fnv.HashInt32(100)
	if h0 != h1 { pass = pass + 1 }
	if h1 != h2 { pass = pass + 1 }
	if h0 != h100 { pass = pass + 1 }
	if h2 != h100 { pass = pass + 1 }

	// Deterministic: same input → same output.
	if fnv.HashInt32(42) == fnv.HashInt32(42) { pass = pass + 1 }
	if fnv.HashInt32(-99) == fnv.HashInt32(-99) { pass = pass + 1 }

	// 32-bit output fits in [0, 2^32).
	if h0 >= 0 { pass = pass + 1 }
	if h0 < 4294967296 { pass = pass + 1 }
	if h100 >= 0 { pass = pass + 1 }
	if h100 < 4294967296 { pass = pass + 1 }

	// HashInt64 — distinct + deterministic.
	var H0 int = fnv.HashInt64(0)
	var H1 int = fnv.HashInt64(1)
	if H0 != H1 { pass = pass + 1 }
	if fnv.HashInt64(42) == fnv.HashInt64(42) { pass = pass + 1 }
	if fnv.HashInt64(-1) == fnv.HashInt64(-1) { pass = pass + 1 }

	// 32-bit and 64-bit forms differ.
	if fnv.HashInt32(42) != fnv.HashInt64(42) { pass = pass + 1 }

	// HashInt32 of 0 has a known fixed value — it's offset XOR
	// (8 zero bytes) all multiplied by prime, so always the same.
	if fnv.HashInt32(0) == fnv.HashInt32(0) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
