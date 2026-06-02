package main
import "log"
import "slices"

// Equal mod 10.
fun eqMod10(a int, b int) bool {
	ret (a % 10) == (b % 10)
}

// Within 5.
fun eqClose(a int, b int) bool {
	var d int = a - b
	if d < 0 { d = -d }
	ret d <= 5
}

fun eqLen(a string, b string) bool {
	ret len(a) == len(b)
}

fun eqStrict(a string, b string) bool { ret a == b }
fun eqIntStrict(a int, b int) bool { ret a == b }

fun main() int {
	var pass int = 0

	// EqualFuncInt — eq-mod-10.
	var a []int = new(3) []int { 13, 22, 35 }
	var b []int = new(3) []int { 3, 12, 5 }
	if slices.EqualFuncInt(a, b, eqMod10) { pass = pass + 1 }

	// Different mod-10 → false.
	var a2 []int = new(3) []int { 13, 22, 35 }
	var b2 []int = new(3) []int { 3, 12, 6 }
	if !slices.EqualFuncInt(a2, b2, eqMod10) { pass = pass + 1 }

	// Length mismatch → false.
	var a3 []int = new(3) []int { 1, 2, 3 }
	var b3 []int = new(2) []int { 1, 2 }
	if !slices.EqualFuncInt(a3, b3, eqMod10) { pass = pass + 1 }

	// Both empty → true.
	var e1 []int = new(0) []int {}
	var e2 []int = new(0) []int {}
	if slices.EqualFuncInt(e1, e2, eqMod10) { pass = pass + 1 }

	// Within-5 fuzzy compare.
	var a4 []int = new(4) []int { 100, 50, 25, 0 }
	var b4 []int = new(4) []int { 102, 48, 28, -3 }
	if slices.EqualFuncInt(a4, b4, eqClose) { pass = pass + 1 }

	// Within-5 fails.
	var a5 []int = new(2) []int { 100, 200 }
	var b5 []int = new(2) []int { 102, 210 }
	if !slices.EqualFuncInt(a5, b5, eqClose) { pass = pass + 1 }

	// Strict — matches EqualInts.
	var a6 []int = new(3) []int { 1, 2, 3 }
	var b6 []int = new(3) []int { 1, 2, 3 }
	if slices.EqualFuncInt(a6, b6, eqIntStrict) { pass = pass + 1 }

	// EqualFuncString — equal-by-length.
	var sa []string = new(3) []string { "abc", "xyz", "qrs" }
	var sb []string = new(3) []string { "def", "uvw", "lmn" }
	if slices.EqualFuncString(sa, sb, eqLen) { pass = pass + 1 }

	// Different lengths → false.
	var sa2 []string = new(2) []string { "a", "bc" }
	var sb2 []string = new(2) []string { "x", "y" }
	if !slices.EqualFuncString(sa2, sb2, eqLen) { pass = pass + 1 }

	// Strict equality predicate matches EqualStrings.
	var sa3 []string = new(3) []string { "apple", "banana", "cherry" }
	var sb3 []string = new(3) []string { "apple", "banana", "cherry" }
	if slices.EqualFuncString(sa3, sb3, eqStrict) { pass = pass + 1 }

	// Length mismatch in String.
	var sa4 []string = new(2) []string { "a", "b" }
	var sb4 []string = new(3) []string { "a", "b", "c" }
	if !slices.EqualFuncString(sa4, sb4, eqStrict) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 11 { ret 42 }
	ret 0
}
