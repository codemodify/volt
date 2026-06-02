package main
import "log"
import "strings"

// Positive test: strings.LongestCommonPrefix + strings.LongestCommonSuffix.

fun main() int {
	var pass int = 0

	// LongestCommonPrefix — basic.
	var a []string = new(3) []string{"interview", "interstellar", "internal"}
	if strings.LongestCommonPrefix(a) == "inter" { pass = pass + 1 }

	// No common prefix.
	var b []string = new(3) []string{"foo", "bar", "baz"}
	if strings.LongestCommonPrefix(b) == "" { pass = pass + 1 }

	// All identical.
	var c []string = new(3) []string{"hello", "hello", "hello"}
	if strings.LongestCommonPrefix(c) == "hello" { pass = pass + 1 }

	// One string is the prefix of the others.
	var d []string = new(3) []string{"pre", "prefix", "prepared"}
	if strings.LongestCommonPrefix(d) == "pre" { pass = pass + 1 }

	// Single element → that element.
	var s1 []string = new(1) []string{"only"}
	if strings.LongestCommonPrefix(s1) == "only" { pass = pass + 1 }

	// Empty input → "".
	var e []string = new(0) []string{}
	if strings.LongestCommonPrefix(e) == "" { pass = pass + 1 }

	// One empty element forces "" result.
	var em []string = new(3) []string{"foo", "", "fooxxx"}
	if strings.LongestCommonPrefix(em) == "" { pass = pass + 1 }

	// Single-character prefix.
	var sc []string = new(3) []string{"axx", "ayy", "azz"}
	if strings.LongestCommonPrefix(sc) == "a" { pass = pass + 1 }

	// LongestCommonSuffix — basic.
	var sa []string = new(3) []string{"running", "jumping", "swimming"}
	if strings.LongestCommonSuffix(sa) == "ing" { pass = pass + 1 }

	// No common suffix.
	var sb []string = new(3) []string{"foo", "bar", "baz"}
	if strings.LongestCommonSuffix(sb) == "" { pass = pass + 1 }

	// All identical.
	var sc2 []string = new(3) []string{"abc", "abc", "abc"}
	if strings.LongestCommonSuffix(sc2) == "abc" { pass = pass + 1 }

	// One is suffix of others.
	var sd []string = new(3) []string{"end", "thend", "frontend"}
	if strings.LongestCommonSuffix(sd) == "end" { pass = pass + 1 }

	// Single element.
	var ss1 []string = new(1) []string{"only"}
	if strings.LongestCommonSuffix(ss1) == "only" { pass = pass + 1 }

	// Empty input.
	var se []string = new(0) []string{}
	if strings.LongestCommonSuffix(se) == "" { pass = pass + 1 }

	// One empty element.
	var sem []string = new(3) []string{"xxxfoo", "", "yyyfoo"}
	if strings.LongestCommonSuffix(sem) == "" { pass = pass + 1 }

	// Single-character suffix.
	var ssc []string = new(3) []string{"xxa", "yya", "zza"}
	if strings.LongestCommonSuffix(ssc) == "a" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
