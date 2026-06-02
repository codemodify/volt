package main
import "log"
import "sort"

// Positive test: sort.IntsAreSortedDesc + StringsAreSortedDesc.

fun main() int {
	var pass int = 0

	// IntsAreSortedDesc — strictly decreasing.
	var a []int = new(5) []int{5, 4, 3, 2, 1}
	if sort.IntsAreSortedDesc(a) { pass = pass + 1 }

	// Non-increasing (allows equals).
	var b []int = new(5) []int{5, 5, 3, 3, 1}
	if sort.IntsAreSortedDesc(b) { pass = pass + 1 }

	// Not sorted (ascending).
	var c []int = new(3) []int{1, 2, 3}
	if !sort.IntsAreSortedDesc(c) { pass = pass + 1 }

	// Almost sorted (one out-of-order pair).
	var d []int = new(4) []int{5, 4, 6, 1}
	if !sort.IntsAreSortedDesc(d) { pass = pass + 1 }

	// Single element.
	var e []int = new(1) []int{42}
	if sort.IntsAreSortedDesc(e) { pass = pass + 1 }

	// Empty.
	var f []int = new(0) []int{}
	if sort.IntsAreSortedDesc(f) { pass = pass + 1 }

	// All equal — trivially non-increasing.
	var g []int = new(4) []int{7, 7, 7, 7}
	if sort.IntsAreSortedDesc(g) { pass = pass + 1 }

	// StringsAreSortedDesc — reverse-lex order.
	var s1 []string = new(3) []string{"cherry", "banana", "apple"}
	if sort.StringsAreSortedDesc(s1) { pass = pass + 1 }

	// Lex-ascending → not desc.
	var s2 []string = new(3) []string{"apple", "banana", "cherry"}
	if !sort.StringsAreSortedDesc(s2) { pass = pass + 1 }

	// Equal-prefix tie — longer first wins desc order ("ab" > "a").
	var s3 []string = new(2) []string{"ab", "a"}
	if sort.StringsAreSortedDesc(s3) { pass = pass + 1 }

	// Equal strings — non-increasing.
	var s4 []string = new(3) []string{"x", "x", "x"}
	if sort.StringsAreSortedDesc(s4) { pass = pass + 1 }

	// Empty / single.
	var s5 []string = new(0) []string{}
	if sort.StringsAreSortedDesc(s5) { pass = pass + 1 }

	var s6 []string = new(1) []string{"only"}
	if sort.StringsAreSortedDesc(s6) { pass = pass + 1 }

	// Mixed-case: "B" < "a" in ASCII (uppercase letters are lower
	// byte values), so {"a", "B"} IS desc.
	var s7 []string = new(2) []string{"a", "B"}
	if sort.StringsAreSortedDesc(s7) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
