package main
import "log"
import "slices"

// Positive test: slices.ReduceInt / ReduceString.

fun add(a int, b int) int { ret a + b }
fun mul(a int, b int) int { ret a * b }
fun maxInt(a int, b int) int { if b > a { ret b }; ret a }
fun concat(a string, b string) string { ret a + b }
fun longest(a string, b string) string {
	if len(b) > len(a) { ret "" + b }
	ret "" + a
}

fun main() int {
	var pass int = 0

	// Sum.
	var a []int = new(5) []int{1, 2, 3, 4, 5}
	if slices.ReduceInt(a, 0, add) == 15 { pass = pass + 1 }

	// Product.
	if slices.ReduceInt(a, 1, mul) == 120 { pass = pass + 1 }

	// Max-with-default — default lower than min element.
	if slices.ReduceInt(a, -1, maxInt) == 5 { pass = pass + 1 }

	// Max-with-default — default higher than every element.
	if slices.ReduceInt(a, 100, maxInt) == 100 { pass = pass + 1 }

	// Sum starting from non-zero init.
	if slices.ReduceInt(a, 10, add) == 25 { pass = pass + 1 }

	// Empty slice → init.
	var e []int = new(0) []int{}
	if slices.ReduceInt(e, 42, add) == 42 { pass = pass + 1 }
	if slices.ReduceInt(e, 1, mul) == 1 { pass = pass + 1 }

	// Single element.
	var s1 []int = new(1) []int{7}
	if slices.ReduceInt(s1, 3, add) == 10 { pass = pass + 1 }

	// ReduceString — concat.
	var s []string = new(3) []string{"hello", " ", "world"}
	if slices.ReduceString(s, "", concat) == "hello world" { pass = pass + 1 }

	// ReduceString — concat with prefix.
	if slices.ReduceString(s, ">>", concat) == ">>hello world" { pass = pass + 1 }

	// ReduceString — longest.
	var w []string = new(4) []string{"a", "bbb", "cc", "dddd"}
	if slices.ReduceString(w, "", longest) == "dddd" { pass = pass + 1 }

	// ReduceString empty.
	var es []string = new(0) []string{}
	if slices.ReduceString(es, "init", concat) == "init" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
