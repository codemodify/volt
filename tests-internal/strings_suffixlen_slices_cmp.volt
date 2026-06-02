package main
import "log"
import "strings"
import "slices"

// Positive test: strings.CommonSuffixLen + slices.CompareInt + CompareString.

fun main() int {
	var pass int = 0

	// CommonSuffixLen basic.
	if strings.CommonSuffixLen("running", "jumping") == 3 { pass = pass + 1 }    // "ing"
	if strings.CommonSuffixLen("abc", "xbc") == 2 { pass = pass + 1 }            // "bc"
	if strings.CommonSuffixLen("foo", "bar") == 0 { pass = pass + 1 }
	if strings.CommonSuffixLen("equal", "equal") == 5 { pass = pass + 1 }

	// Shorter exhausts.
	if strings.CommonSuffixLen("xx", "yxx") == 2 { pass = pass + 1 }

	// Empties.
	if strings.CommonSuffixLen("", "anything") == 0 { pass = pass + 1 }
	if strings.CommonSuffixLen("anything", "") == 0 { pass = pass + 1 }
	if strings.CommonSuffixLen("", "") == 0 { pass = pass + 1 }

	// Single byte.
	if strings.CommonSuffixLen("a", "a") == 1 { pass = pass + 1 }
	if strings.CommonSuffixLen("a", "b") == 0 { pass = pass + 1 }

	// CompareInt basic.
	var a []int = new(3) []int{1, 2, 3}
	var b []int = new(3) []int{1, 2, 3}
	if slices.CompareInt(a, b) == 0 { pass = pass + 1 }

	var c []int = new(3) []int{1, 2, 4}
	if slices.CompareInt(a, c) == -1 { pass = pass + 1 }
	if slices.CompareInt(c, a) == 1 { pass = pass + 1 }

	// Length tiebreaker — shorter is less.
	var sh []int = new(2) []int{1, 2}
	var ln []int = new(3) []int{1, 2, 0}   // even if last is 0, longer wins
	if slices.CompareInt(sh, ln) == -1 { pass = pass + 1 }
	if slices.CompareInt(ln, sh) == 1 { pass = pass + 1 }

	// Empty vs empty.
	var e1 []int = new(0) []int{}
	var e2 []int = new(0) []int{}
	if slices.CompareInt(e1, e2) == 0 { pass = pass + 1 }

	// Empty vs non-empty.
	if slices.CompareInt(e1, a) == -1 { pass = pass + 1 }
	if slices.CompareInt(a, e1) == 1 { pass = pass + 1 }

	// CompareString.
	var sa []string = new(3) []string{"a", "b", "c"}
	var sb []string = new(3) []string{"a", "b", "c"}
	if slices.CompareString(sa, sb) == 0 { pass = pass + 1 }

	var sc []string = new(3) []string{"a", "b", "d"}
	if slices.CompareString(sa, sc) == -1 { pass = pass + 1 }
	if slices.CompareString(sc, sa) == 1 { pass = pass + 1 }

	// CompareString length tiebreaker.
	var ssh []string = new(2) []string{"a", "b"}
	var sln []string = new(3) []string{"a", "b", "c"}
	if slices.CompareString(ssh, sln) == -1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
