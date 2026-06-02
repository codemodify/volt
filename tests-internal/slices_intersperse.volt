package main
import "log"
import "slices"

// Positive test: slices.IntersperseInt / IntersperseString.

fun main() int {
	var pass int = 0

	// IntersperseInt — basic three-element.
	var a []int = new(3) []int{1, 2, 3}
	var ai []int = slices.IntersperseInt(a, 0)
	if len(ai) == 5 { pass = pass + 1 }
	if ai[0] == 1 { pass = pass + 1 }
	if ai[1] == 0 { pass = pass + 1 }
	if ai[2] == 2 { pass = pass + 1 }
	if ai[3] == 0 { pass = pass + 1 }
	if ai[4] == 3 { pass = pass + 1 }

	// Two elements — single separator.
	var b []int = new(2) []int{7, 9}
	var bi []int = slices.IntersperseInt(b, -1)
	if len(bi) == 3 { pass = pass + 1 }
	if bi[0] == 7 { pass = pass + 1 }
	if bi[1] == -1 { pass = pass + 1 }
	if bi[2] == 9 { pass = pass + 1 }

	// Single element — passthrough, no separator.
	var c []int = new(1) []int{42}
	var ci []int = slices.IntersperseInt(c, 0)
	if len(ci) == 1 { pass = pass + 1 }
	if ci[0] == 42 { pass = pass + 1 }

	// Empty.
	var d []int = new(0) []int{}
	var di []int = slices.IntersperseInt(d, 99)
	if len(di) == 0 { pass = pass + 1 }

	// IntersperseString — three words with comma.
	var s []string = new(3) []string{"a", "b", "c"}
	var si []string = slices.IntersperseString(s, ",")
	if len(si) == 5 { pass = pass + 1 }
	if si[0] == "a" { pass = pass + 1 }
	if si[1] == "," { pass = pass + 1 }
	if si[3] == "," { pass = pass + 1 }
	if si[4] == "c" { pass = pass + 1 }

	// IntersperseString single + empty.
	var s1 []string = new(1) []string{"only"}
	var si1 []string = slices.IntersperseString(s1, "X")
	if len(si1) == 1 { pass = pass + 1 }
	if si1[0] == "only" { pass = pass + 1 }

	var s0 []string = new(0) []string{}
	var si0 []string = slices.IntersperseString(s0, "Y")
	if len(si0) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
