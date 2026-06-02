package main
import "log"
import "math"
import "slices"

// Positive test: math.DigitalRoot + slices.IsSubsetInt + IsSubsetString.

fun main() int {
	var pass int = 0

	// DigitalRoot single-digit.
	if math.DigitalRoot(0) == 0 { pass = pass + 1 }
	if math.DigitalRoot(1) == 1 { pass = pass + 1 }
	if math.DigitalRoot(9) == 9 { pass = pass + 1 }

	// DigitalRoot two-digit needing one iteration.
	if math.DigitalRoot(10) == 1 { pass = pass + 1 }
	if math.DigitalRoot(38) == 2 { pass = pass + 1 }   // 3+8=11 → 1+1=2
	if math.DigitalRoot(99) == 9 { pass = pass + 1 }   // 9+9=18 → 1+8=9

	// DigitalRoot three+ digit.
	if math.DigitalRoot(123) == 6 { pass = pass + 1 }      // 1+2+3=6
	if math.DigitalRoot(456) == 6 { pass = pass + 1 }      // 4+5+6=15 → 6
	if math.DigitalRoot(999) == 9 { pass = pass + 1 }      // 27 → 9
	if math.DigitalRoot(12345) == 6 { pass = pass + 1 }    // 15 → 6

	// DigitalRoot negative — ignores sign.
	if math.DigitalRoot(-99) == 9 { pass = pass + 1 }

	// Property: DigitalRoot(n) == 1 + (n - 1) mod 9 for n > 0.
	if math.DigitalRoot(37) == 1 { pass = pass + 1 }   // 37 mod 9 = 1
	if math.DigitalRoot(45) == 9 { pass = pass + 1 }   // 45 mod 9 = 0 → 9

	// IsSubsetInt basic.
	var a []int = new(3) []int{1, 2, 3}
	var b []int = new(5) []int{1, 2, 3, 4, 5}
	if slices.IsSubsetInt(a, b) { pass = pass + 1 }

	// Not a subset.
	var c []int = new(3) []int{1, 2, 99}
	if !slices.IsSubsetInt(c, b) { pass = pass + 1 }

	// Empty a → trivially subset.
	var e []int = new(0) []int{}
	if slices.IsSubsetInt(e, b) { pass = pass + 1 }

	// Empty b — only empty a is subset.
	var nb []int = new(0) []int{}
	if !slices.IsSubsetInt(a, nb) { pass = pass + 1 }
	if slices.IsSubsetInt(e, nb) { pass = pass + 1 }

	// Reflexive — s is subset of s.
	if slices.IsSubsetInt(a, a) { pass = pass + 1 }

	// Multiplicity ignored — a has duplicates but still subset.
	var dup []int = new(4) []int{1, 1, 2, 2}
	if slices.IsSubsetInt(dup, b) { pass = pass + 1 }

	// IsSubsetString.
	var sa []string = new(2) []string{"a", "b"}
	var sb []string = new(4) []string{"a", "b", "c", "d"}
	if slices.IsSubsetString(sa, sb) { pass = pass + 1 }

	var sc []string = new(2) []string{"a", "zzz"}
	if !slices.IsSubsetString(sc, sb) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
