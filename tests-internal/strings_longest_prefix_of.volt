package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty list → "".
	var e []string = new(0) []string {}
	if strings.LongestPrefixOf("hello", e) == "" { pass = pass + 1 }
	var e2 []string = new(0) []string {}
	if strings.LongestSuffixOf("hello", e2) == "" { pass = pass + 1 }

	// No match.
	var p1 []string = new(2) []string { "abc", "def" }
	if strings.LongestPrefixOf("hello", p1) == "" { pass = pass + 1 }

	// Longest wins regardless of position (short-first).
	var p2 []string = new(3) []string { "a", "ab", "abc" }
	if strings.LongestPrefixOf("abcdef", p2) == "abc" { pass = pass + 1 }

	// Longest wins regardless of position (long-first).
	var p3 []string = new(3) []string { "abc", "ab", "a" }
	if strings.LongestPrefixOf("abcdef", p3) == "abc" { pass = pass + 1 }

	// Stable tie-break on equal length.
	var p4 []string = new(2) []string { "ab", "cd" }
	if strings.LongestPrefixOf("abcd", p4) == "ab" { pass = pass + 1 }

	// Multiple matches with non-trivial lengths.
	var p5 []string = new(4) []string { "/api/v1/", "/api/", "/", "/api/v1/users/" }
	if strings.LongestPrefixOf("/api/v1/users/alice", p5) == "/api/v1/users/" { pass = pass + 1 }

	// Empty in list matches first; longer must override.
	var p6 []string = new(3) []string { "", "abc", "abcdef" }
	if strings.LongestPrefixOf("abcdefghi", p6) == "abcdef" { pass = pass + 1 }

	// Only the empty prefix.
	var p7 []string = new(1) []string { "" }
	if strings.LongestPrefixOf("hello", p7) == "" { pass = pass + 1 }

	// LongestSuffixOf basics.
	var s1 []string = new(3) []string { ".gz", ".tar.gz", ".tar" }
	if strings.LongestSuffixOf("file.tar.gz", s1) == ".tar.gz" { pass = pass + 1 }

	// Order doesn't matter for LongestSuffixOf.
	var s2 []string = new(3) []string { ".tar.gz", ".gz", ".tar" }
	if strings.LongestSuffixOf("file.tar.gz", s2) == ".tar.gz" { pass = pass + 1 }

	// Empty s.
	var p8 []string = new(2) []string { "a", "b" }
	if strings.LongestPrefixOf("", p8) == "" { pass = pass + 1 }

	// Routing-precision use case.
	var routes []string = new(4) []string { "/", "/admin/", "/admin/users/", "/static/" }
	var url string = "/admin/users/alice"
	var matched string = strings.LongestPrefixOf(url, routes)
	if matched == "/admin/users/" { pass = pass + 1 }

	// File-type use case where order-independence matters.
	var exts []string = new(4) []string { ".gz", ".bz2", ".tar.gz", ".tar" }
	var fn string = "data.tar.gz"
	var ext string = strings.LongestSuffixOf(fn, exts)
	if ext == ".tar.gz" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
