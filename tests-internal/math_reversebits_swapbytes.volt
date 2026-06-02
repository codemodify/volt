package main
import "log"
import "math"

// Positive test: math.ReverseBits64 + math.SwapBytes64.

fun main() int {
	var pass int = 0

	// ReverseBits64 — 0 and all-ones invariants.
	if math.ReverseBits64(0) == 0 { pass = pass + 1 }
	if math.ReverseBits64(-1) == -1 { pass = pass + 1 }

	// ReverseBits64 — bit 0 ↔ bit 63.
	if math.ReverseBits64(1) == math.MinInt { pass = pass + 1 }
	if math.ReverseBits64(math.MinInt) == 1 { pass = pass + 1 }

	// ReverseBits64 — bit 1 ↔ bit 62.
	if math.ReverseBits64(2) == 4611686018427387904 { pass = pass + 1 }

	// ReverseBits64 — symmetric (palindromic) bit patterns.
	// 0x8000000000000001 (MinInt | 1) reverses to itself.
	if math.ReverseBits64(math.MinInt | 1) == (math.MinInt | 1) { pass = pass + 1 }

	// ReverseBits64 — involution (apply twice → identity).
	if math.ReverseBits64(math.ReverseBits64(42)) == 42 { pass = pass + 1 }
	if math.ReverseBits64(math.ReverseBits64(99999)) == 99999 { pass = pass + 1 }
	if math.ReverseBits64(math.ReverseBits64(-7)) == -7 { pass = pass + 1 }

	// SwapBytes64 — 0 and all-ones invariants.
	if math.SwapBytes64(0) == 0 { pass = pass + 1 }
	if math.SwapBytes64(-1) == -1 { pass = pass + 1 }

	// SwapBytes64 — single byte at low → high.
	if math.SwapBytes64(1) == 72057594037927936 { pass = pass + 1 }   // 0x0100000000000000
	if math.SwapBytes64(0xff) == -72057594037927936 { pass = pass + 1 } // 0xff00000000000000 → signed = -72057594037927936

	// SwapBytes64 — well-known 4-byte pattern.
	// 0x01020304 in 64 bits is 0x0000000001020304; reversed = 0x0403020100000000.
	if math.SwapBytes64(0x01020304) == 0x0403020100000000 { pass = pass + 1 }

	// SwapBytes64 — 8-byte palindromic stays put.
	// 0x0102030400000000 reverses to 0x0000000004030201 = 67305985
	// And 0x0102030404030201 reverses to itself.
	if math.SwapBytes64(0x0102030404030201) == 0x0102030404030201 { pass = pass + 1 }

	// SwapBytes64 — involution.
	if math.SwapBytes64(math.SwapBytes64(42)) == 42 { pass = pass + 1 }
	if math.SwapBytes64(math.SwapBytes64(-12345)) == -12345 { pass = pass + 1 }
	if math.SwapBytes64(math.SwapBytes64(1234567890)) == 1234567890 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
