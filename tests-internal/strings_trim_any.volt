package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty list → unchanged.
	var emp []string = new(0) []string {}
	if strings.TrimAnyPrefix("hello", emp) == "hello" { pass = pass + 1 }
	var emp2 []string = new(0) []string {}
	if strings.TrimAnySuffix("hello", emp2) == "hello" { pass = pass + 1 }

	// No match → unchanged.
	var p1 []string = new(2) []string { "abc", "def" }
	if strings.TrimAnyPrefix("hello", p1) == "hello" { pass = pass + 1 }
	var p2 []string = new(2) []string { ".jpg", ".png" }
	if strings.TrimAnySuffix("readme.md", p2) == "readme.md" { pass = pass + 1 }

	// Match.
	var p3 []string = new(2) []string { "http://", "https://" }
	if strings.TrimAnyPrefix("http://example.com", p3) == "example.com" { pass = pass + 1 }
	var p4 []string = new(2) []string { "http://", "https://" }
	if strings.TrimAnyPrefix("https://example.com", p4) == "example.com" { pass = pass + 1 }

	// First-match-wins.
	var p5 []string = new(3) []string { "a", "ab", "abc" }
	if strings.TrimAnyPrefix("abcdef", p5) == "bcdef" { pass = pass + 1 }

	// Longest version uses LongestPrefixOf semantics.
	var p6 []string = new(3) []string { "a", "ab", "abc" }
	if strings.TrimLongestPrefix("abcdef", p6) == "def" { pass = pass + 1 }
	var p7 []string = new(3) []string { "abc", "ab", "a" }
	if strings.TrimLongestPrefix("abcdef", p7) == "def" { pass = pass + 1 }

	// Suffix variants.
	var s1 []string = new(3) []string { ".tar.gz", ".gz", ".tar" }
	if strings.TrimAnySuffix("file.tar.gz", s1) == "file" { pass = pass + 1 }

	// Order matters for TrimAnySuffix.
	var s2 []string = new(2) []string { ".gz", ".tar.gz" }
	if strings.TrimAnySuffix("file.tar.gz", s2) == "file.tar" { pass = pass + 1 }   // first match .gz strips just .gz

	// TrimLongestSuffix order-independent.
	var s3 []string = new(2) []string { ".gz", ".tar.gz" }
	if strings.TrimLongestSuffix("file.tar.gz", s3) == "file" { pass = pass + 1 }
	var s4 []string = new(2) []string { ".tar.gz", ".gz" }
	if strings.TrimLongestSuffix("file.tar.gz", s4) == "file" { pass = pass + 1 }

	// Empty s.
	var p8 []string = new(2) []string { "a", "b" }
	if strings.TrimAnyPrefix("", p8) == "" { pass = pass + 1 }
	if strings.TrimLongestSuffix("", p8) == "" { pass = pass + 1 }

	// URL normalization use case.
	var url string = "https://example.com/api"
	var schemes []string = new(2) []string { "http://", "https://" }
	if strings.TrimAnyPrefix(url, schemes) == "example.com/api" { pass = pass + 1 }

	// Archive filename stem extraction.
	var fn string = "data.tar.gz"
	var exts []string = new(3) []string { ".gz", ".bz2", ".tar.gz" }
	var stem string = strings.TrimLongestSuffix(fn, exts)
	if stem == "data" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
