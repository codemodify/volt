package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// LCP — basic.
	if slices.LongestCommonPrefixString(new(4) []string { "a", "b", "c", "d" }, new(4) []string { "a", "b", "x", "y" }) == 2 { pass = pass + 1 }
	if slices.LongestCommonPrefixString(new(3) []string { "x", "y", "z" }, new(3) []string { "x", "y", "z" }) == 3 { pass = pass + 1 }

	// LCP — disagree on first.
	if slices.LongestCommonPrefixString(new(2) []string { "a", "b" }, new(2) []string { "x", "y" }) == 0 { pass = pass + 1 }

	// LCP — empty operand.
	if slices.LongestCommonPrefixString(new(0) []string {}, new(2) []string { "a", "b" }) == 0 { pass = pass + 1 }
	if slices.LongestCommonPrefixString(new(0) []string {}, new(0) []string {}) == 0 { pass = pass + 1 }

	// LCP — prefix-of.
	if slices.LongestCommonPrefixString(new(2) []string { "foo", "bar" }, new(4) []string { "foo", "bar", "baz", "qux" }) == 2 { pass = pass + 1 }

	// LCS — basic.
	if slices.LongestCommonSuffixString(new(4) []string { "a", "b", "c", "d" }, new(4) []string { "x", "y", "c", "d" }) == 2 { pass = pass + 1 }

	// LCS — equal.
	if slices.LongestCommonSuffixString(new(2) []string { "a", "b" }, new(2) []string { "a", "b" }) == 2 { pass = pass + 1 }

	// LCS — disagree on last.
	if slices.LongestCommonSuffixString(new(3) []string { "x", "y", "z" }, new(3) []string { "x", "y", "w" }) == 0 { pass = pass + 1 }

	// LCS — empty operand.
	if slices.LongestCommonSuffixString(new(0) []string {}, new(2) []string { "a", "b" }) == 0 { pass = pass + 1 }

	// LCS — suffix-of.
	if slices.LongestCommonSuffixString(new(2) []string { "baz", "qux" }, new(4) []string { "foo", "bar", "baz", "qux" }) == 2 { pass = pass + 1 }

	// LCP + LCS sanity: equal slices → both == len.
	var same []string = new(3) []string { "a", "b", "c" }
	if slices.LongestCommonPrefixString(same, same) == 3 { pass = pass + 1 }
	if slices.LongestCommonSuffixString(same, same) == 3 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
