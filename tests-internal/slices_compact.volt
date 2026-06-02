package main
import "log"
import "slices"

// Positive test: slices.CompactInt / CompactString. Removes
// consecutive duplicates only — non-adjacent duplicates survive.

fun main() int {
	var pass int = 0

	// Consecutive duplicates collapse, non-adjacent duplicates stay.
	var a []int = new(7) []int{1, 1, 2, 2, 2, 3, 1}
	var r1 []int = slices.CompactInt(a)
	if len(r1) == 4 { pass = pass + 1 }
	if r1[0] == 1 { pass = pass + 1 }
	if r1[1] == 2 { pass = pass + 1 }
	if r1[2] == 3 { pass = pass + 1 }
	if r1[3] == 1 { pass = pass + 1 }

	// No duplicates → unchanged.
	var b []int = new(4) []int{1, 2, 3, 4}
	var r2 []int = slices.CompactInt(b)
	if len(r2) == 4 { pass = pass + 1 }
	if r2[3] == 4 { pass = pass + 1 }

	// All same → single element.
	var c []int = new(5) []int{7, 7, 7, 7, 7}
	var r3 []int = slices.CompactInt(c)
	if len(r3) == 1 { pass = pass + 1 }
	if r3[0] == 7 { pass = pass + 1 }

	// Empty → empty.
	var d []int = new(0) []int{}
	var r4 []int = slices.CompactInt(d)
	if len(r4) == 0 { pass = pass + 1 }

	// Single element.
	var e []int = new(1) []int{42}
	var r5 []int = slices.CompactInt(e)
	if len(r5) == 1 { pass = pass + 1 }
	if r5[0] == 42 { pass = pass + 1 }

	// Strings variant.
	var f []string = new(5) []string{"foo", "foo", "bar", "bar", "baz"}
	var r6 []string = slices.CompactString(f)
	if len(r6) == 3 { pass = pass + 1 }
	if r6[0] == "foo" { pass = pass + 1 }
	if r6[1] == "bar" { pass = pass + 1 }
	if r6[2] == "baz" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
