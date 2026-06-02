package main
import "log"
import "slices"

// Positive test: slices.PrefixProductInt + slices.SuffixProductInt.

fun main() int {
	var pass int = 0

	// PrefixProductInt — basic.
	var p1 []int = slices.PrefixProductInt(new(5) []int { 1, 2, 3, 4, 5 })
	if len(p1) == 5 { pass = pass + 1 }
	if p1[0] == 1 { pass = pass + 1 }
	if p1[1] == 2 { pass = pass + 1 }
	if p1[2] == 6 { pass = pass + 1 }
	if p1[3] == 24 { pass = pass + 1 }
	if p1[4] == 120 { pass = pass + 1 }

	// PrefixProductInt — contains zero.
	var p2 []int = slices.PrefixProductInt(new(4) []int { 2, 3, 0, 5 })
	if p2[0] == 2 { pass = pass + 1 }
	if p2[1] == 6 { pass = pass + 1 }
	if p2[2] == 0 { pass = pass + 1 }
	if p2[3] == 0 { pass = pass + 1 }

	// PrefixProductInt — negative factors.
	var p3 []int = slices.PrefixProductInt(new(3) []int { 2, -3, 4 })
	if p3[0] == 2 { pass = pass + 1 }
	if p3[1] == -6 { pass = pass + 1 }
	if p3[2] == -24 { pass = pass + 1 }

	// PrefixProductInt — empty.
	var p4 []int = slices.PrefixProductInt(new(0) []int {})
	if len(p4) == 0 { pass = pass + 1 }

	// PrefixProductInt — single.
	var p5 []int = slices.PrefixProductInt(new(1) []int { 7 })
	if p5[0] == 7 { pass = pass + 1 }

	// SuffixProductInt — basic.
	var s1 []int = slices.SuffixProductInt(new(5) []int { 1, 2, 3, 4, 5 })
	if len(s1) == 5 { pass = pass + 1 }
	if s1[0] == 120 { pass = pass + 1 }
	if s1[1] == 120 { pass = pass + 1 }
	if s1[2] == 60 { pass = pass + 1 }
	if s1[3] == 20 { pass = pass + 1 }
	if s1[4] == 5 { pass = pass + 1 }

	// SuffixProductInt — empty.
	var s2 []int = slices.SuffixProductInt(new(0) []int {})
	if len(s2) == 0 { pass = pass + 1 }

	// SuffixProductInt — single.
	var s3 []int = slices.SuffixProductInt(new(1) []int { 7 })
	if s3[0] == 7 { pass = pass + 1 }

	// Consistency: PrefixProduct[last] == SuffixProduct[0] (both = total product).
	var sample []int = new(4) []int { 2, 3, 4, 5 }
	var pp []int = slices.PrefixProductInt(sample)
	var sp []int = slices.SuffixProductInt(sample)
	if pp[3] == sp[0] { pass = pass + 1 }
	if pp[3] == 120 { pass = pass + 1 }

	// Consistency with ProductInts.
	if pp[3] == slices.ProductInts(sample) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
