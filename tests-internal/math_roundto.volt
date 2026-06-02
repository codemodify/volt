package main
import "log"
import "math"

fun main() int {
	var pass int = 0

	// Already on a multiple → unchanged.
	if math.RoundToMultiple(0, 5) == 0 { pass = pass + 1 }
	if math.RoundToMultiple(10, 5) == 10 { pass = pass + 1 }
	if math.RoundToMultiple(25, 5) == 25 { pass = pass + 1 }

	// Round down (rem < k/2).
	if math.RoundToMultiple(11, 5) == 10 { pass = pass + 1 }
	if math.RoundToMultiple(12, 5) == 10 { pass = pass + 1 }
	if math.RoundToMultiple(1, 5) == 0 { pass = pass + 1 }
	if math.RoundToMultiple(2, 5) == 0 { pass = pass + 1 }

	// Round up (rem > k/2).
	if math.RoundToMultiple(13, 5) == 15 { pass = pass + 1 }
	if math.RoundToMultiple(14, 5) == 15 { pass = pass + 1 }
	if math.RoundToMultiple(3, 5) == 5 { pass = pass + 1 }
	if math.RoundToMultiple(4, 5) == 5 { pass = pass + 1 }

	// Tie (rem == k/2): round up.
	// k=10, n=5 → tie → 10.
	if math.RoundToMultiple(5, 10) == 10 { pass = pass + 1 }
	// k=4, n=2 → tie (2*2 >= 4) → 4.
	if math.RoundToMultiple(2, 4) == 4 { pass = pass + 1 }
	// k=4, n=6 → tie (rem=2, 2*2>=4) → 8.
	if math.RoundToMultiple(6, 4) == 8 { pass = pass + 1 }

	// k <= 0 → unchanged.
	if math.RoundToMultiple(7, 0) == 7 { pass = pass + 1 }
	if math.RoundToMultiple(7, -3) == 7 { pass = pass + 1 }

	// k == 1 → unchanged (every int is a multiple of 1).
	if math.RoundToMultiple(42, 1) == 42 { pass = pass + 1 }

	// Negative n: mirror.
	if math.RoundToMultiple(-1, 5) == 0 { pass = pass + 1 }
	if math.RoundToMultiple(-2, 5) == 0 { pass = pass + 1 }
	if math.RoundToMultiple(-3, 5) == -5 { pass = pass + 1 }
	if math.RoundToMultiple(-4, 5) == -5 { pass = pass + 1 }
	if math.RoundToMultiple(-5, 5) == -5 { pass = pass + 1 }
	if math.RoundToMultiple(-7, 5) == -5 { pass = pass + 1 }
	if math.RoundToMultiple(-8, 5) == -10 { pass = pass + 1 }
	if math.RoundToMultiple(-10, 5) == -10 { pass = pass + 1 }

	// Snap-to-grid use case: grid size 16, various positions.
	if math.RoundToMultiple(7, 16) == 0 { pass = pass + 1 }
	if math.RoundToMultiple(8, 16) == 16 { pass = pass + 1 }   // tie
	if math.RoundToMultiple(20, 16) == 16 { pass = pass + 1 }
	if math.RoundToMultiple(24, 16) == 32 { pass = pass + 1 }   // tie

	// Audio sample-rate alignment: round to nearest 1024.
	if math.RoundToMultiple(500, 1024) == 0 { pass = pass + 1 }
	if math.RoundToMultiple(1500, 1024) == 1024 { pass = pass + 1 }
	if math.RoundToMultiple(1600, 1024) == 2048 { pass = pass + 1 }

	// Cross-property: RoundToMultiple result is a multiple of k.
	var r1 int = math.RoundToMultiple(123, 7)
	if r1 % 7 == 0 { pass = pass + 1 }
	var r2 int = math.RoundToMultiple(-456, 13)
	if r2 % 13 == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 34 { ret 42 }
	ret 0
}
