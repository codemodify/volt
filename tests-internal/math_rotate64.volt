package main
import "log"
import "math"

// Positive test: math.RotateLeft64 + math.RotateRight64.

fun main() int {
	var pass int = 0

	// RotateLeft64 — basic.
	if math.RotateLeft64(1, 0) == 1 { pass = pass + 1 }
	if math.RotateLeft64(1, 1) == 2 { pass = pass + 1 }
	if math.RotateLeft64(1, 4) == 16 { pass = pass + 1 }
	if math.RotateLeft64(1, 8) == 256 { pass = pass + 1 }

	// RotateLeft64 — 0 stays 0.
	if math.RotateLeft64(0, 5) == 0 { pass = pass + 1 }

	// RotateLeft64 — all-ones (-1 in two's complement) stays all-ones.
	if math.RotateLeft64(-1, 1) == -1 { pass = pass + 1 }
	if math.RotateLeft64(-1, 31) == -1 { pass = pass + 1 }
	if math.RotateLeft64(-1, 63) == -1 { pass = pass + 1 }

	// RotateLeft64 — k mod 64 reduction.
	if math.RotateLeft64(1, 64) == 1 { pass = pass + 1 }
	if math.RotateLeft64(1, 65) == 2 { pass = pass + 1 }
	if math.RotateLeft64(1, 128) == 1 { pass = pass + 1 }

	// RotateLeft64 — negative k.
	if math.RotateLeft64(2, -1) == 1 { pass = pass + 1 }

	// RotateLeft64 — high bit wraps to low.
	// MinInt = 1 << 63 is the only bit set at position 63.
	// Rotating left by 1 brings it to position 0 → value 1.
	if math.RotateLeft64(math.MinInt, 1) == 1 { pass = pass + 1 }

	// RotateRight64 — basic.
	if math.RotateRight64(2, 0) == 2 { pass = pass + 1 }
	if math.RotateRight64(2, 1) == 1 { pass = pass + 1 }
	if math.RotateRight64(16, 4) == 1 { pass = pass + 1 }
	if math.RotateRight64(256, 8) == 1 { pass = pass + 1 }

	// RotateRight64 — 0 stays 0.
	if math.RotateRight64(0, 5) == 0 { pass = pass + 1 }

	// RotateRight64 — all-ones stays all-ones.
	if math.RotateRight64(-1, 1) == -1 { pass = pass + 1 }
	if math.RotateRight64(-1, 63) == -1 { pass = pass + 1 }

	// RotateRight64 — low bit wraps to high.
	// 1 rotated right by 1 → MinInt (bit at position 63).
	if math.RotateRight64(1, 1) == math.MinInt { pass = pass + 1 }

	// RotateRight64 — k mod 64.
	if math.RotateRight64(2, 64) == 2 { pass = pass + 1 }
	if math.RotateRight64(2, 65) == 1 { pass = pass + 1 }

	// Identity: RotateLeft(RotateRight(n, k), k) == n.
	if math.RotateLeft64(math.RotateRight64(42, 7), 7) == 42 { pass = pass + 1 }
	if math.RotateLeft64(math.RotateRight64(-1, 13), 13) == -1 { pass = pass + 1 }

	// Identity: RotateLeft(n, k) == RotateRight(n, 64 - k) for k in [1, 63].
	if math.RotateLeft64(42, 10) == math.RotateRight64(42, 54) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
