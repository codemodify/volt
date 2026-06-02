package main
import "log"
import "slices"

// Positive test: slices.RunLengthEncodeInt + slices.RunLengthDecodeInt.

fun main() int {
	var pass int = 0

	var values []int = new(0) []int {}
	var counts []int = new(0) []int {}

	// Encode — basic.
	values, counts = slices.RunLengthEncodeInt(new(6) []int { 1, 1, 1, 2, 3, 3 })
	if len(values) == 3 { pass = pass + 1 }
	if len(counts) == 3 { pass = pass + 1 }
	if values[0] == 1 { pass = pass + 1 }
	if counts[0] == 3 { pass = pass + 1 }
	if values[1] == 2 { pass = pass + 1 }
	if counts[1] == 1 { pass = pass + 1 }
	if values[2] == 3 { pass = pass + 1 }
	if counts[2] == 2 { pass = pass + 1 }

	// Encode — all-distinct.
	values, counts = slices.RunLengthEncodeInt(new(4) []int { 5, 6, 7, 8 })
	if len(values) == 4 { pass = pass + 1 }
	if counts[0] == 1 { pass = pass + 1 }
	if counts[3] == 1 { pass = pass + 1 }

	// Encode — all-same.
	values, counts = slices.RunLengthEncodeInt(new(5) []int { 7, 7, 7, 7, 7 })
	if len(values) == 1 { pass = pass + 1 }
	if values[0] == 7 { pass = pass + 1 }
	if counts[0] == 5 { pass = pass + 1 }

	// Encode — empty.
	values, counts = slices.RunLengthEncodeInt(new(0) []int {})
	if len(values) == 0 { pass = pass + 1 }
	if len(counts) == 0 { pass = pass + 1 }

	// Encode — single element.
	values, counts = slices.RunLengthEncodeInt(new(1) []int { 42 })
	if len(values) == 1 { pass = pass + 1 }
	if values[0] == 42 { pass = pass + 1 }
	if counts[0] == 1 { pass = pass + 1 }

	// Decode — basic.
	var dec []int = slices.RunLengthDecodeInt(new(3) []int { 1, 2, 3 }, new(3) []int { 2, 1, 3 })
	if len(dec) == 6 { pass = pass + 1 }
	if dec[0] == 1 { pass = pass + 1 }
	if dec[1] == 1 { pass = pass + 1 }
	if dec[2] == 2 { pass = pass + 1 }
	if dec[3] == 3 { pass = pass + 1 }
	if dec[5] == 3 { pass = pass + 1 }

	// Decode — empty inputs.
	var emptyDec []int = slices.RunLengthDecodeInt(new(0) []int {}, new(0) []int {})
	if len(emptyDec) == 0 { pass = pass + 1 }

	// Decode — uneven lengths stops at min.
	var unevenDec []int = slices.RunLengthDecodeInt(new(3) []int { 1, 2, 3 }, new(2) []int { 1, 1 })
	if len(unevenDec) == 2 { pass = pass + 1 }
	if unevenDec[0] == 1 { pass = pass + 1 }
	if unevenDec[1] == 2 { pass = pass + 1 }

	// Decode — non-positive counts skipped.
	var skipDec []int = slices.RunLengthDecodeInt(new(3) []int { 1, 2, 3 }, new(3) []int { 1, 0, 2 })
	if len(skipDec) == 3 { pass = pass + 1 }
	if skipDec[0] == 1 { pass = pass + 1 }
	if skipDec[1] == 3 { pass = pass + 1 }
	if skipDec[2] == 3 { pass = pass + 1 }

	// Roundtrip: decode(encode(s)) == s.
	var orig []int = new(7) []int { 1, 1, 2, 2, 2, 3, 1 }
	values, counts = slices.RunLengthEncodeInt(orig)
	var round []int = slices.RunLengthDecodeInt(values, counts)
	if len(round) == 7 { pass = pass + 1 }
	if round[0] == 1 { pass = pass + 1 }
	if round[2] == 2 { pass = pass + 1 }
	if round[5] == 3 { pass = pass + 1 }
	if round[6] == 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 38 { ret 42 }
	ret 0
}
