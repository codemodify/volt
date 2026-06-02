package main
import "log"
import "slices"
import "strings"

fun isLower(s string) bool {
	if len(s) == 0 { ret false }
	var c byte = s[0]
	if c >= 97 {
		if c <= 122 { ret true }
	}
	ret false
}

fun isShort(s string) bool { ret len(s) < 4 }
fun alwaysTrueS(s string) bool { ret true }

fun main() int {
	var pass int = 0

	// TakeWhileString — by first-char-lowercase.
	var t1 []string = slices.TakeWhileString(new(5) []string { "alpha", "beta", "Gamma", "delta", "echo" }, isLower)
	if len(t1) == 2 { pass = pass + 1 }
	if t1[0] == "alpha" { pass = pass + 1 }
	if t1[1] == "beta" { pass = pass + 1 }

	// TakeWhileString — by length.
	var t2 []string = slices.TakeWhileString(new(4) []string { "ab", "cd", "ef", "long" }, isShort)
	if len(t2) == 3 { pass = pass + 1 }
	if t2[2] == "ef" { pass = pass + 1 }

	// TakeWhileString — pred fails on first.
	var t3 []string = slices.TakeWhileString(new(3) []string { "Long", "ab", "cd" }, isShort)
	if len(t3) == 0 { pass = pass + 1 }

	// TakeWhileString — empty.
	var t4 []string = slices.TakeWhileString(new(0) []string {}, isLower)
	if len(t4) == 0 { pass = pass + 1 }

	// TakeWhileString — true throughout.
	var t5 []string = slices.TakeWhileString(new(3) []string { "a", "b", "c" }, alwaysTrueS)
	if len(t5) == 3 { pass = pass + 1 }

	// DropWhileString — basic.
	var d1 []string = slices.DropWhileString(new(5) []string { "alpha", "beta", "Gamma", "delta", "echo" }, isLower)
	if len(d1) == 3 { pass = pass + 1 }
	if d1[0] == "Gamma" { pass = pass + 1 }
	if d1[2] == "echo" { pass = pass + 1 }

	// DropWhileString — pred fails on first → no drop.
	var d2 []string = slices.DropWhileString(new(3) []string { "Long", "ab", "cd" }, isShort)
	if len(d2) == 3 { pass = pass + 1 }

	// DropWhileString — true throughout → empty.
	var d3 []string = slices.DropWhileString(new(3) []string { "a", "b", "c" }, alwaysTrueS)
	if len(d3) == 0 { pass = pass + 1 }

	// DropWhileString — empty.
	var d4 []string = slices.DropWhileString(new(0) []string {}, isShort)
	if len(d4) == 0 { pass = pass + 1 }

	// Partition identity.
	var sample []string = new(5) []string { "alpha", "beta", "Gamma", "delta", "echo" }
	if len(slices.TakeWhileString(sample, isLower)) + len(slices.DropWhileString(sample, isLower)) == 5 { pass = pass + 1 }

	// Closure with HasPrefix from strings package.
	var withPrefix []string = slices.TakeWhileString(new(4) []string { "x-foo", "x-bar", "baz", "x-qux" }, fun(s string) bool { ret strings.HasPrefix(s, "x-") })
	if len(withPrefix) == 2 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
