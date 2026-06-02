package main
import "log"
import "sort"

fun main() int {
	var pass int = 0

	// Empty.
	var e []string = new(0) []string {}
	e = sort.StringsByLen(e)
	if len(e) == 0 { pass = pass + 1 }

	// Single.
	var s1 []string = new(1) []string { "hello" }
	s1 = sort.StringsByLen(s1)
	if len(s1) == 1 { pass = pass + 1 }
	if s1[0] == "hello" { pass = pass + 1 }

	// Multi: shortest first.
	var s2 []string = new(4) []string { "alpha", "bb", "ccc", "d" }
	s2 = sort.StringsByLen(s2)
	if s2[0] == "d" { pass = pass + 1 }
	if s2[1] == "bb" { pass = pass + 1 }
	if s2[2] == "ccc" { pass = pass + 1 }
	if s2[3] == "alpha" { pass = pass + 1 }

	// Descending.
	var s3 []string = new(4) []string { "d", "bb", "ccc", "alpha" }
	s3 = sort.StringsByLenDesc(s3)
	if s3[0] == "alpha" { pass = pass + 1 }
	if s3[1] == "ccc" { pass = pass + 1 }
	if s3[2] == "bb" { pass = pass + 1 }
	if s3[3] == "d" { pass = pass + 1 }

	// Stable: equal lengths retain order (asc).
	var s4 []string = new(4) []string { "ab", "cd", "ef", "gh" }
	s4 = sort.StringsByLen(s4)
	if s4[0] == "ab" { pass = pass + 1 }
	if s4[1] == "cd" { pass = pass + 1 }
	if s4[2] == "ef" { pass = pass + 1 }
	if s4[3] == "gh" { pass = pass + 1 }

	// Stable in desc.
	var s5 []string = new(4) []string { "aa", "bb", "cc", "dd" }
	s5 = sort.StringsByLenDesc(s5)
	if s5[0] == "aa" { pass = pass + 1 }
	if s5[3] == "dd" { pass = pass + 1 }

	// Already sorted asc.
	var s6 []string = new(3) []string { "a", "bb", "ccc" }
	s6 = sort.StringsByLen(s6)
	if s6[0] == "a" { pass = pass + 1 }
	if s6[2] == "ccc" { pass = pass + 1 }

	// Reverse-sorted gets reordered.
	var s7 []string = new(3) []string { "ccc", "bb", "a" }
	s7 = sort.StringsByLen(s7)
	if s7[0] == "a" { pass = pass + 1 }
	if s7[1] == "bb" { pass = pass + 1 }
	if s7[2] == "ccc" { pass = pass + 1 }

	// Empty strings.
	var s8 []string = new(3) []string { "x", "", "yy" }
	s8 = sort.StringsByLen(s8)
	if s8[0] == "" { pass = pass + 1 }
	if s8[1] == "x" { pass = pass + 1 }
	if s8[2] == "yy" { pass = pass + 1 }

	// Trie-friendly use case: longest-first prefix list.
	var routes []string = new(4) []string { "/api/", "/api/v1/users/", "/", "/api/v1/" }
	routes = sort.StringsByLenDesc(routes)
	if routes[0] == "/api/v1/users/" { pass = pass + 1 }
	if routes[3] == "/" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
