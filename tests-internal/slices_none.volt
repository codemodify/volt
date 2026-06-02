package main
import "log"
import "slices"

fun isNeg(x int) bool {
	if x < 0 { ret true }
	ret false
}

fun isZero(x int) bool {
	if x == 0 { ret true }
	ret false
}

fun isBlank(s string) bool {
	if s == "" { ret true }
	ret false
}

fun startsWithA(s string) bool {
	if len(s) == 0 { ret false }
	if s[0] == 97 { ret true }
	ret false
}

fun main() int {
	var pass int = 0

	// NoneInt — no element matches → true.
	var a []int = new(4) []int { 1, 2, 3, 4 }
	if slices.NoneInt(a, isNeg) { pass = pass + 1 }

	// NoneInt — at least one match → false.
	var b []int = new(3) []int { 1, -2, 3 }
	if !slices.NoneInt(b, isNeg) { pass = pass + 1 }

	// NoneInt — every element matches → false.
	var c []int = new(3) []int { -1, -2, -3 }
	if !slices.NoneInt(c, isNeg) { pass = pass + 1 }

	// NoneInt — empty slice → true (vacuous truth).
	var d []int = new(0) []int {}
	if slices.NoneInt(d, isNeg) { pass = pass + 1 }

	// NoneInt — single match.
	var e []int = new(1) []int { 0 }
	if !slices.NoneInt(e, isZero) { pass = pass + 1 }

	// NoneInt — single non-match.
	var f []int = new(1) []int { 5 }
	if slices.NoneInt(f, isZero) { pass = pass + 1 }

	// NoneInt — complementary to AnyInt.
	var g []int = new(3) []int { 1, 2, 3 }
	if slices.AnyInt(g, isNeg) == false { pass = pass + 1 }
	if slices.NoneInt(g, isNeg) == true { pass = pass + 1 }

	// NoneString — parallel suite.
	var sa []string = new(3) []string { "x", "y", "z" }
	if slices.NoneString(sa, isBlank) { pass = pass + 1 }

	var sb []string = new(3) []string { "x", "", "z" }
	if !slices.NoneString(sb, isBlank) { pass = pass + 1 }

	var sc []string = new(0) []string {}
	if slices.NoneString(sc, isBlank) { pass = pass + 1 }

	// NoneString — startsWithA predicate.
	var sd []string = new(3) []string { "apple", "banana", "cherry" }
	if !slices.NoneString(sd, startsWithA) { pass = pass + 1 }
	var se []string = new(3) []string { "banana", "cherry", "durian" }
	if slices.NoneString(se, startsWithA) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
