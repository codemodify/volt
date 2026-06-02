package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// CommonPrefixAll — basic shared directory prefix.
	if strings.CommonPrefixAll(new(3) []string { "/usr/local/bin", "/usr/local/lib", "/usr/local/share" }) == "/usr/local/" { pass = pass + 1 }

	// CommonPrefixAll — partial overlap.
	if strings.CommonPrefixAll(new(3) []string { "abcdef", "abcxyz", "abcq" }) == "abc" { pass = pass + 1 }

	// CommonPrefixAll — no common.
	if strings.CommonPrefixAll(new(3) []string { "apple", "banana", "cherry" }) == "" { pass = pass + 1 }

	// CommonPrefixAll — single element.
	if strings.CommonPrefixAll(new(1) []string { "hello" }) == "hello" { pass = pass + 1 }

	// CommonPrefixAll — empty input.
	if strings.CommonPrefixAll(new(0) []string {}) == "" { pass = pass + 1 }

	// CommonPrefixAll — one empty string forces empty result.
	if strings.CommonPrefixAll(new(3) []string { "abc", "", "abc" }) == "" { pass = pass + 1 }

	// CommonPrefixAll — all identical.
	if strings.CommonPrefixAll(new(3) []string { "same", "same", "same" }) == "same" { pass = pass + 1 }

	// CommonPrefixAll — prefix-of relationship.
	if strings.CommonPrefixAll(new(3) []string { "foo", "foobar", "foobaz" }) == "foo" { pass = pass + 1 }

	// CommonSuffixAll — file-extension family.
	if strings.CommonSuffixAll(new(3) []string { "a.tar.gz", "b.tar.gz", "c.tar.gz" }) == ".tar.gz" { pass = pass + 1 }

	// CommonSuffixAll — no common.
	if strings.CommonSuffixAll(new(2) []string { "foo", "bar" }) == "" { pass = pass + 1 }

	// CommonSuffixAll — single.
	if strings.CommonSuffixAll(new(1) []string { "abc" }) == "abc" { pass = pass + 1 }

	// CommonSuffixAll — empty input.
	if strings.CommonSuffixAll(new(0) []string {}) == "" { pass = pass + 1 }

	// CommonSuffixAll — all identical.
	if strings.CommonSuffixAll(new(2) []string { "abc", "abc" }) == "abc" { pass = pass + 1 }

	// CommonSuffixAll — short tail.
	if strings.CommonSuffixAll(new(3) []string { "running", "jumping", "swimming" }) == "ing" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
