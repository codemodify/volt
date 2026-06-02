package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty inputs → 0.
	var e1 []int = new(0) []int {}
	var e2 []int = new(0) []int {}
	if slices.CommonPrefixLenInt(e1, e2) == 0 { pass = pass + 1 }
	var e3 []int = new(0) []int {}
	var e4 []int = new(0) []int {}
	if slices.CommonSuffixLenInt(e3, e4) == 0 { pass = pass + 1 }

	// One empty → 0.
	var s1 []int = new(3) []int { 1, 2, 3 }
	var ee []int = new(0) []int {}
	if slices.CommonPrefixLenInt(s1, ee) == 0 { pass = pass + 1 }
	var s1b []int = new(3) []int { 1, 2, 3 }
	var ee2 []int = new(0) []int {}
	if slices.CommonSuffixLenInt(s1b, ee2) == 0 { pass = pass + 1 }

	// Identical → min(len).
	var a1 []int = new(4) []int { 1, 2, 3, 4 }
	var b1 []int = new(4) []int { 1, 2, 3, 4 }
	if slices.CommonPrefixLenInt(a1, b1) == 4 { pass = pass + 1 }
	var a1b []int = new(4) []int { 1, 2, 3, 4 }
	var b1b []int = new(4) []int { 1, 2, 3, 4 }
	if slices.CommonSuffixLenInt(a1b, b1b) == 4 { pass = pass + 1 }

	// Partial prefix match.
	var a2 []int = new(5) []int { 1, 2, 3, 4, 5 }
	var b2 []int = new(5) []int { 1, 2, 3, 9, 9 }
	if slices.CommonPrefixLenInt(a2, b2) == 3 { pass = pass + 1 }

	// Partial suffix match.
	var a3 []int = new(5) []int { 9, 9, 3, 4, 5 }
	var b3 []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.CommonSuffixLenInt(a3, b3) == 3 { pass = pass + 1 }

	// No agreement.
	var a4 []int = new(3) []int { 1, 2, 3 }
	var b4 []int = new(3) []int { 4, 5, 6 }
	if slices.CommonPrefixLenInt(a4, b4) == 0 { pass = pass + 1 }
	var a4b []int = new(3) []int { 1, 2, 3 }
	var b4b []int = new(3) []int { 4, 5, 6 }
	if slices.CommonSuffixLenInt(a4b, b4b) == 0 { pass = pass + 1 }

	// Different lengths, full short match prefix.
	var a5 []int = new(3) []int { 1, 2, 3 }
	var b5 []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.CommonPrefixLenInt(a5, b5) == 3 { pass = pass + 1 }
	var a5b []int = new(3) []int { 1, 2, 3 }
	var b5b []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.CommonPrefixLenInt(b5b, a5b) == 3 { pass = pass + 1 }

	// Different lengths, suffix.
	var a6 []int = new(3) []int { 3, 4, 5 }
	var b6 []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.CommonSuffixLenInt(a6, b6) == 3 { pass = pass + 1 }

	// Strings.
	var sa []string = new(4) []string { "alpha", "bravo", "charlie", "delta" }
	var sb []string = new(4) []string { "alpha", "bravo", "echo", "delta" }
	if slices.CommonPrefixLenString(sa, sb) == 2 { pass = pass + 1 }

	var sa2 []string = new(4) []string { "alpha", "bravo", "charlie", "delta" }
	var sb2 []string = new(4) []string { "x", "y", "charlie", "delta" }
	if slices.CommonSuffixLenString(sa2, sb2) == 2 { pass = pass + 1 }

	var sa3 []string = new(0) []string {}
	var sb3 []string = new(2) []string { "a", "b" }
	if slices.CommonPrefixLenString(sa3, sb3) == 0 { pass = pass + 1 }

	// Cross-property: HasPrefixInts iff CommonPrefixLen >= len(prefix).
	var s2 []int = new(5) []int { 1, 2, 3, 4, 5 }
	var s2b []int = new(5) []int { 1, 2, 3, 4, 5 }
	var pf []int = new(3) []int { 1, 2, 3 }
	var pfb []int = new(3) []int { 1, 2, 3 }
	if slices.HasPrefixInts(s2, pf) == (slices.CommonPrefixLenInt(s2b, pfb) >= 3) { pass = pass + 1 }

	// Path-prefix use case: shared path components.
	var p1 []string = new(4) []string { "usr", "local", "bin", "tool" }
	var p2 []string = new(4) []string { "usr", "local", "lib", "lib1" }
	if slices.CommonPrefixLenString(p1, p2) == 2 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
