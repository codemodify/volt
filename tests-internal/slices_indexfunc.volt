package main
import "log"
import "slices"

// Positive test: slices.IndexFuncInt + IndexFuncString — first
// element index satisfying a predicate.

fun isEven(x int) bool { ret (x % 2) == 0 }
fun isNeg(x int) bool { ret x < 0 }
fun startsA(x string) bool {
	if len(x) == 0 { ret false }
	ret x[0] == 65
}
fun startsZ(x string) bool {
	if len(x) == 0 { ret false }
	ret x[0] == 90
}

fun main() int {
	var pass int = 0

	// IndexFuncInt: first even.
	var a []int = new(5) []int{1, 3, 4, 5, 6}
	if slices.IndexFuncInt(a, isEven) == 2 { pass = pass + 1 }

	// IndexFuncInt: no match.
	var b []int = new(3) []int{1, 3, 5}
	if slices.IndexFuncInt(b, isEven) == -1 { pass = pass + 1 }

	// IndexFuncInt: match at index 0.
	var c []int = new(3) []int{2, 4, 6}
	if slices.IndexFuncInt(c, isEven) == 0 { pass = pass + 1 }

	// IndexFuncInt: empty slice.
	var d []int = new(0) []int{}
	if slices.IndexFuncInt(d, isEven) == -1 { pass = pass + 1 }

	// IndexFuncInt: negative predicate.
	var e []int = new(4) []int{5, 7, -2, 9}
	if slices.IndexFuncInt(e, isNeg) == 2 { pass = pass + 1 }

	// IndexFuncString: first starting with 'A'.
	var s []string = new(4) []string{"foo", "Apple", "bar", "Aardvark"}
	if slices.IndexFuncString(s, startsA) == 1 { pass = pass + 1 }

	// IndexFuncString: no match.
	var s2 []string = new(3) []string{"foo", "bar", "baz"}
	if slices.IndexFuncString(s2, startsZ) == -1 { pass = pass + 1 }

	// IndexFuncString: empty string in slice handled gracefully.
	var s3 []string = new(3) []string{"", "", "Zest"}
	if slices.IndexFuncString(s3, startsZ) == 2 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 8 { ret 42 }
	ret 0
}
