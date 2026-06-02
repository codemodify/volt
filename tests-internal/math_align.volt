package main
import "log"
import "math"

// Positive test: math.AlignUp + math.AlignDown.

fun main() int {
	var pass int = 0

	// AlignUp — basic 8-byte alignment.
	if math.AlignUp(0, 8) == 0 { pass = pass + 1 }
	if math.AlignUp(1, 8) == 8 { pass = pass + 1 }
	if math.AlignUp(7, 8) == 8 { pass = pass + 1 }
	if math.AlignUp(8, 8) == 8 { pass = pass + 1 }
	if math.AlignUp(9, 8) == 16 { pass = pass + 1 }
	if math.AlignUp(15, 8) == 16 { pass = pass + 1 }
	if math.AlignUp(16, 8) == 16 { pass = pass + 1 }
	if math.AlignUp(17, 8) == 24 { pass = pass + 1 }

	// AlignUp — page-size (4096) alignment.
	if math.AlignUp(4096, 4096) == 4096 { pass = pass + 1 }
	if math.AlignUp(4097, 4096) == 8192 { pass = pass + 1 }
	if math.AlignUp(1, 4096) == 4096 { pass = pass + 1 }

	// AlignUp — k == 1 is no-op.
	if math.AlignUp(42, 1) == 42 { pass = pass + 1 }

	// AlignUp — degenerate inputs return n.
	if math.AlignUp(10, 0) == 10 { pass = pass + 1 }
	if math.AlignUp(10, -1) == 10 { pass = pass + 1 }
	if math.AlignUp(-5, 8) == -5 { pass = pass + 1 }
	if math.AlignUp(0, 8) == 0 { pass = pass + 1 }

	// AlignDown — basic 8-byte.
	if math.AlignDown(0, 8) == 0 { pass = pass + 1 }
	if math.AlignDown(1, 8) == 0 { pass = pass + 1 }
	if math.AlignDown(7, 8) == 0 { pass = pass + 1 }
	if math.AlignDown(8, 8) == 8 { pass = pass + 1 }
	if math.AlignDown(15, 8) == 8 { pass = pass + 1 }
	if math.AlignDown(16, 8) == 16 { pass = pass + 1 }
	if math.AlignDown(17, 8) == 16 { pass = pass + 1 }

	// AlignDown — page-size.
	if math.AlignDown(4096, 4096) == 4096 { pass = pass + 1 }
	if math.AlignDown(4097, 4096) == 4096 { pass = pass + 1 }
	if math.AlignDown(8191, 4096) == 4096 { pass = pass + 1 }
	if math.AlignDown(8192, 4096) == 8192 { pass = pass + 1 }

	// AlignDown — degenerate.
	if math.AlignDown(10, 0) == 10 { pass = pass + 1 }
	if math.AlignDown(-5, 8) == -5 { pass = pass + 1 }
	if math.AlignDown(0, 8) == 0 { pass = pass + 1 }

	// Identity: AlignDown(n, k) <= n <= AlignUp(n, k).
	if math.AlignDown(13, 4) == 12 { pass = pass + 1 }
	if math.AlignUp(13, 4) == 16 { pass = pass + 1 }
	if math.AlignDown(13, 4) <= 13 { pass = pass + 1 }
	if 13 <= math.AlignUp(13, 4) { pass = pass + 1 }

	// AlignUp(AlignDown(n)) == AlignDown(n) (idempotence on the result).
	if math.AlignUp(math.AlignDown(100, 16), 16) == math.AlignDown(100, 16) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 35 { ret 42 }
	ret 0
}
