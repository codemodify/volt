package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty list → "".
	var emp []string = new(0) []string {}
	if strings.PrefixOf("hello", emp) == "" { pass = pass + 1 }
	var emp2 []string = new(0) []string {}
	if strings.SuffixOf("hello", emp2) == "" { pass = pass + 1 }

	// No match.
	var p1 []string = new(2) []string { "abc", "def" }
	if strings.PrefixOf("hello", p1) == "" { pass = pass + 1 }
	var p2 []string = new(2) []string { ".jpg", ".png" }
	if strings.SuffixOf("readme.md", p2) == "" { pass = pass + 1 }

	// Match.
	var p3 []string = new(2) []string { "http://", "https://" }
	if strings.PrefixOf("http://example.com", p3) == "http://" { pass = pass + 1 }
	var p4 []string = new(2) []string { "http://", "https://" }
	if strings.PrefixOf("https://example.com", p4) == "https://" { pass = pass + 1 }

	// First-match-wins.
	var p5 []string = new(3) []string { "a", "ab", "abc" }
	if strings.PrefixOf("abcdef", p5) == "a" { pass = pass + 1 }

	// Longest-first ordering controlled by caller.
	var p6 []string = new(3) []string { "abc", "ab", "a" }
	if strings.PrefixOf("abcdef", p6) == "abc" { pass = pass + 1 }

	// Suffix match.
	var s1 []string = new(3) []string { ".jpg", ".png", ".gif" }
	if strings.SuffixOf("photo.png", s1) == ".png" { pass = pass + 1 }
	var s2 []string = new(2) []string { ".tar.gz", ".gz" }
	if strings.SuffixOf("archive.tar.gz", s2) == ".tar.gz" { pass = pass + 1 }

	// Order matters for suffix too.
	var s3 []string = new(2) []string { ".gz", ".tar.gz" }
	if strings.SuffixOf("archive.tar.gz", s3) == ".gz" { pass = pass + 1 }

	// Empty pattern in list always matches as prefix.
	var p7 []string = new(2) []string { "", "abc" }
	if strings.PrefixOf("hello", p7) == "" { pass = pass + 1 }   // empty matches first

	// Cross-check with HasAnyPrefix.
	var p8 []string = new(2) []string { "http://", "https://" }
	var p8b []string = new(2) []string { "http://", "https://" }
	if (strings.PrefixOf("http://", p8) != "") == strings.HasAnyPrefix("http://", p8b) { pass = pass + 1 }

	// Empty s.
	var p9 []string = new(2) []string { "a", "b" }
	if strings.PrefixOf("", p9) == "" { pass = pass + 1 }

	// Routing use case.
	var routes []string = new(3) []string { "/api/", "/admin/", "/static/" }
	var url string = "/api/users"
	var route string = strings.PrefixOf(url, routes)
	if route == "/api/" { pass = pass + 1 }

	// File-type detection.
	var exts []string = new(4) []string { ".tar.gz", ".tar.bz2", ".zip", ".gz" }
	var fn string = "data.tar.gz"
	var ext string = strings.SuffixOf(fn, exts)
	if ext == ".tar.gz" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
