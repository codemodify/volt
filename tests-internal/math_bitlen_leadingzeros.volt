package main
import "log"
import "math"

// Positive test: math.BitLen + math.LeadingZeros.

fun main() int {
	var pass int = 0

	// BitLen — basic.
	if math.BitLen(0) == 0 { pass = pass + 1 }
	if math.BitLen(1) == 1 { pass = pass + 1 }
	if math.BitLen(2) == 2 { pass = pass + 1 }
	if math.BitLen(3) == 2 { pass = pass + 1 }
	if math.BitLen(4) == 3 { pass = pass + 1 }
	if math.BitLen(7) == 3 { pass = pass + 1 }
	if math.BitLen(8) == 4 { pass = pass + 1 }
	if math.BitLen(255) == 8 { pass = pass + 1 }
	if math.BitLen(256) == 9 { pass = pass + 1 }
	if math.BitLen(1023) == 10 { pass = pass + 1 }
	if math.BitLen(1024) == 11 { pass = pass + 1 }
	if math.BitLen(65535) == 16 { pass = pass + 1 }
	if math.BitLen(65536) == 17 { pass = pass + 1 }

	// BitLen — negatives use absolute value.
	if math.BitLen(-1) == 1 { pass = pass + 1 }
	if math.BitLen(-255) == 8 { pass = pass + 1 }

	// LeadingZeros — basic identities.
	if math.LeadingZeros(0) == 64 { pass = pass + 1 }
	if math.LeadingZeros(1) == 63 { pass = pass + 1 }
	if math.LeadingZeros(2) == 62 { pass = pass + 1 }
	if math.LeadingZeros(3) == 62 { pass = pass + 1 }
	if math.LeadingZeros(4) == 61 { pass = pass + 1 }
	if math.LeadingZeros(255) == 56 { pass = pass + 1 }
	if math.LeadingZeros(256) == 55 { pass = pass + 1 }
	if math.LeadingZeros(65535) == 48 { pass = pass + 1 }
	if math.LeadingZeros(65536) == 47 { pass = pass + 1 }

	// LeadingZeros — large values.
	if math.LeadingZeros(1048576) == 43 { pass = pass + 1 }

	// LeadingZeros — negatives use absolute value.
	if math.LeadingZeros(-1) == 63 { pass = pass + 1 }
	if math.LeadingZeros(-256) == 55 { pass = pass + 1 }

	// Identity: BitLen(n) + LeadingZeros(n) == 64.
	if math.BitLen(42) + math.LeadingZeros(42) == 64 { pass = pass + 1 }
	if math.BitLen(99999) + math.LeadingZeros(99999) == 64 { pass = pass + 1 }
	if math.BitLen(1) + math.LeadingZeros(1) == 64 { pass = pass + 1 }

	// BitLen(2^k) == k+1 (matches IsPowerOfTwo + 1).
	if math.BitLen(1024) == 11 { pass = pass + 1 }
	if math.BitLen(1048576) == 21 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 32 { ret 42 }
	ret 0
}
