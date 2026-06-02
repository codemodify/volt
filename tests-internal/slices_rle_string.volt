package main
import "log"
import "slices"

// Positive test: slices.RunLengthEncodeString + RunLengthDecodeString.

fun main() int {
	var pass int = 0

	var values []string = new(0) []string {}
	var counts []int = new(0) []int {}

	// Encode — basic.
	values, counts = slices.RunLengthEncodeString(new(5) []string { "a", "a", "b", "c", "c" })
	if len(values) == 3 { pass = pass + 1 }
	if values[0] == "a" { pass = pass + 1 }
	if counts[0] == 2 { pass = pass + 1 }
	if values[1] == "b" { pass = pass + 1 }
	if counts[1] == 1 { pass = pass + 1 }
	if values[2] == "c" { pass = pass + 1 }
	if counts[2] == 2 { pass = pass + 1 }

	// Encode — all-distinct.
	values, counts = slices.RunLengthEncodeString(new(3) []string { "x", "y", "z" })
	if len(values) == 3 { pass = pass + 1 }
	if counts[0] == 1 { pass = pass + 1 }

	// Encode — all-same.
	values, counts = slices.RunLengthEncodeString(new(4) []string { "foo", "foo", "foo", "foo" })
	if len(values) == 1 { pass = pass + 1 }
	if counts[0] == 4 { pass = pass + 1 }

	// Encode — empty.
	values, counts = slices.RunLengthEncodeString(new(0) []string {})
	if len(values) == 0 { pass = pass + 1 }

	// Encode — single.
	values, counts = slices.RunLengthEncodeString(new(1) []string { "solo" })
	if len(values) == 1 { pass = pass + 1 }
	if values[0] == "solo" { pass = pass + 1 }
	if counts[0] == 1 { pass = pass + 1 }

	// Decode — basic.
	var dec []string = slices.RunLengthDecodeString(new(2) []string { "x", "y" }, new(2) []int { 3, 2 })
	if len(dec) == 5 { pass = pass + 1 }
	if dec[0] == "x" { pass = pass + 1 }
	if dec[2] == "x" { pass = pass + 1 }
	if dec[3] == "y" { pass = pass + 1 }
	if dec[4] == "y" { pass = pass + 1 }

	// Decode — empty.
	var emptyDec []string = slices.RunLengthDecodeString(new(0) []string {}, new(0) []int {})
	if len(emptyDec) == 0 { pass = pass + 1 }

	// Decode — non-positive counts skipped.
	var skipDec []string = slices.RunLengthDecodeString(new(3) []string { "a", "b", "c" }, new(3) []int { 1, 0, 1 })
	if len(skipDec) == 2 { pass = pass + 1 }
	if skipDec[0] == "a" { pass = pass + 1 }
	if skipDec[1] == "c" { pass = pass + 1 }

	// Roundtrip.
	var orig []string = new(6) []string { "alpha", "alpha", "beta", "gamma", "gamma", "alpha" }
	values, counts = slices.RunLengthEncodeString(orig)
	var round []string = slices.RunLengthDecodeString(values, counts)
	if len(round) == 6 { pass = pass + 1 }
	if round[0] == "alpha" { pass = pass + 1 }
	if round[2] == "beta" { pass = pass + 1 }
	if round[3] == "gamma" { pass = pass + 1 }
	if round[5] == "alpha" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 29 { ret 42 }
	ret 0
}
