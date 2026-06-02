package main
import "log"
import "slices"

// Positive test: slices.IntsToStrings / StringsToInts.

fun main() int {
	var pass int = 0

	// IntsToStrings: standard case.
	var a []int = new(4) []int{1, 2, 30, -7}
	var sa []string = slices.IntsToStrings(a)
	if len(sa) == 4 { pass = pass + 1 }
	if sa[0] == "1" { pass = pass + 1 }
	if sa[2] == "30" { pass = pass + 1 }
	if sa[3] == "-7" { pass = pass + 1 }

	// Empty input.
	var b []int = new(0) []int{}
	var sb []string = slices.IntsToStrings(b)
	if len(sb) == 0 { pass = pass + 1 }

	// StringsToInts: success.
	var s1 []string = new(3) []string{"10", "20", "-5"}
	var i1 []int = new(0) []int{}
	var e1 error = nil
	i1, e1 = slices.StringsToInts(s1)
	if e1 == nil { pass = pass + 1 }
	if len(i1) == 3 { pass = pass + 1 }
	if i1[0] == 10 { pass = pass + 1 }
	if i1[2] == -5 { pass = pass + 1 }

	// StringsToInts: parse error returns (empty, error).
	var s2 []string = new(3) []string{"1", "two", "3"}
	var i2 []int = new(0) []int{}
	var e2 error = nil
	i2, e2 = slices.StringsToInts(s2)
	if e2 != nil { pass = pass + 1 }
	if len(i2) == 0 { pass = pass + 1 }

	// StringsToInts: empty input.
	var s3 []string = new(0) []string{}
	var i3 []int = new(0) []int{}
	var e3 error = nil
	i3, e3 = slices.StringsToInts(s3)
	if e3 == nil { pass = pass + 1 }
	if len(i3) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
