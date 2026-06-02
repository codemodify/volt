package main
import "log"
import "slices"

// Positive test: slices.RemoveFirstInt + RemoveFirstString + RemoveAllInt + RemoveAllString.

fun main() int {
	var pass int = 0

	// RemoveFirstInt — first occurrence.
	var a []int = new(5) []int{1, 2, 3, 2, 1}
	var ra []int = slices.RemoveFirstInt(a, 2)
	if len(ra) == 4 { pass = pass + 1 }
	if ra[0] == 1 { pass = pass + 1 }
	if ra[1] == 3 { pass = pass + 1 }
	if ra[2] == 2 { pass = pass + 1 }   // second occurrence kept
	if ra[3] == 1 { pass = pass + 1 }

	// Not present.
	var rb []int = slices.RemoveFirstInt(a, 99)
	if len(rb) == 5 { pass = pass + 1 }
	if rb[0] == 1 { pass = pass + 1 }

	// Empty input.
	var em []int = new(0) []int{}
	if len(slices.RemoveFirstInt(em, 1)) == 0 { pass = pass + 1 }

	// Single match.
	var sg []int = new(1) []int{42}
	var rsg []int = slices.RemoveFirstInt(sg, 42)
	if len(rsg) == 0 { pass = pass + 1 }

	// RemoveAllInt — all occurrences.
	var rc []int = slices.RemoveAllInt(a, 1)
	if len(rc) == 3 { pass = pass + 1 }
	if rc[0] == 2 { pass = pass + 1 }
	if rc[2] == 2 { pass = pass + 1 }

	// RemoveAllInt — none.
	var rd []int = slices.RemoveAllInt(a, 99)
	if len(rd) == 5 { pass = pass + 1 }

	// RemoveAllInt — empty.
	if len(slices.RemoveAllInt(em, 1)) == 0 { pass = pass + 1 }

	// RemoveAllInt — all elements removed.
	var same []int = new(3) []int{7, 7, 7}
	if len(slices.RemoveAllInt(same, 7)) == 0 { pass = pass + 1 }

	// Original unchanged.
	if a[0] == 1 { pass = pass + 1 }
	if a[3] == 2 { pass = pass + 1 }

	// RemoveFirstString.
	var s []string = new(4) []string{"a", "b", "c", "b"}
	var rs []string = slices.RemoveFirstString(s, "b")
	if len(rs) == 3 { pass = pass + 1 }
	if rs[1] == "c" { pass = pass + 1 }
	if rs[2] == "b" { pass = pass + 1 }   // second still there

	// RemoveAllString.
	var rss []string = slices.RemoveAllString(s, "b")
	if len(rss) == 2 { pass = pass + 1 }
	if rss[0] == "a" { pass = pass + 1 }
	if rss[1] == "c" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
