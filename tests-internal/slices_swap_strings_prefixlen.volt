package main
import "log"
import "slices"
import "strings"

// Positive test: slices.SwapInt + SwapString + strings.CommonPrefixLen.

fun main() int {
	var pass int = 0

	// SwapInt basic.
	var a []int = new(5) []int{1, 2, 3, 4, 5}
	a = slices.SwapInt(a, 1, 3)
	if a[1] == 4 { pass = pass + 1 }
	if a[3] == 2 { pass = pass + 1 }
	if a[0] == 1 { pass = pass + 1 }
	if a[2] == 3 { pass = pass + 1 }
	if a[4] == 5 { pass = pass + 1 }

	// SwapInt same index → unchanged.
	a = slices.SwapInt(a, 0, 0)
	if a[0] == 1 { pass = pass + 1 }

	// SwapInt out of bounds → no-op.
	a = slices.SwapInt(a, 0, 100)
	if a[0] == 1 { pass = pass + 1 }
	a = slices.SwapInt(a, -1, 0)
	if a[0] == 1 { pass = pass + 1 }

	// SwapInt round-trip.
	var b []int = new(4) []int{10, 20, 30, 40}
	b = slices.SwapInt(b, 0, 3)
	b = slices.SwapInt(b, 0, 3)
	if b[0] == 10 { pass = pass + 1 }
	if b[3] == 40 { pass = pass + 1 }

	// SwapString.
	var s []string = new(3) []string{"alpha", "beta", "gamma"}
	s = slices.SwapString(s, 0, 2)
	if s[0] == "gamma" { pass = pass + 1 }
	if s[2] == "alpha" { pass = pass + 1 }

	// CommonPrefixLen basic.
	if strings.CommonPrefixLen("hello", "help") == 3 { pass = pass + 1 }
	if strings.CommonPrefixLen("abc", "abcde") == 3 { pass = pass + 1 }   // shorter ends first
	if strings.CommonPrefixLen("foo", "bar") == 0 { pass = pass + 1 }
	if strings.CommonPrefixLen("equal", "equal") == 5 { pass = pass + 1 }

	// One empty.
	if strings.CommonPrefixLen("", "anything") == 0 { pass = pass + 1 }
	if strings.CommonPrefixLen("anything", "") == 0 { pass = pass + 1 }
	if strings.CommonPrefixLen("", "") == 0 { pass = pass + 1 }

	// Single-byte tests.
	if strings.CommonPrefixLen("a", "a") == 1 { pass = pass + 1 }
	if strings.CommonPrefixLen("a", "b") == 0 { pass = pass + 1 }

	// LongestCommonPrefix sanity — its length equals CommonPrefixLen.
	var p string = strings.LongestCommonPrefix(new(3) []string{"interview", "interstellar", "internal"})
	if len(p) == 5 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
