package main
import "log"
import "slices"

// Positive test: slices.LastIndexFuncInt / LastIndexFuncString /
// CountFuncInt / CountFuncString.

fun isEven(x int) bool { ret (x % 2) == 0 }
fun isLong(s string) bool { ret len(s) >= 4 }
fun isPos(x int) bool { ret x > 0 }

fun main() int {
	var pass int = 0

	// LastIndexFuncInt: last even element.
	var a []int = new(6) []int{1, 2, 3, 4, 5, 6}
	if slices.LastIndexFuncInt(a, isEven) == 5 { pass = pass + 1 }

	// LastIndexFuncInt: no match.
	var b []int = new(3) []int{1, 3, 5}
	if slices.LastIndexFuncInt(b, isEven) == -1 { pass = pass + 1 }

	// LastIndexFuncInt: match only at index 0.
	var c []int = new(3) []int{4, 1, 3}
	if slices.LastIndexFuncInt(c, isEven) == 0 { pass = pass + 1 }

	// LastIndexFuncInt: empty.
	var d []int = new(0) []int{}
	if slices.LastIndexFuncInt(d, isEven) == -1 { pass = pass + 1 }

	// LastIndexFuncString.
	var s1 []string = new(4) []string{"a", "bb", "ccc", "dddd"}
	if slices.LastIndexFuncString(s1, isLong) == 3 { pass = pass + 1 }

	// LastIndexFuncString: no match.
	var s2 []string = new(3) []string{"a", "b", "c"}
	if slices.LastIndexFuncString(s2, isLong) == -1 { pass = pass + 1 }

	// CountFuncInt.
	var e []int = new(6) []int{1, 2, 3, 4, 5, 6}
	if slices.CountFuncInt(e, isEven) == 3 { pass = pass + 1 }

	// CountFuncInt: zero matches.
	var f []int = new(3) []int{1, 3, 5}
	if slices.CountFuncInt(f, isEven) == 0 { pass = pass + 1 }

	// CountFuncInt: all match.
	var g []int = new(4) []int{2, 4, 6, 8}
	if slices.CountFuncInt(g, isEven) == 4 { pass = pass + 1 }

	// CountFuncInt: empty.
	var h []int = new(0) []int{}
	if slices.CountFuncInt(h, isEven) == 0 { pass = pass + 1 }

	// CountFuncString.
	var s3 []string = new(5) []string{"a", "longer", "xy", "alsobig", "z"}
	if slices.CountFuncString(s3, isLong) == 2 { pass = pass + 1 }

	// CountFuncInt with isPos.
	var k []int = new(5) []int{-2, 0, 5, -1, 7}
	if slices.CountFuncInt(k, isPos) == 2 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
