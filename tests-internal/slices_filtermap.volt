package main
import "log"
import "slices"

fun isPos(x int) bool { ret x > 0 }
fun isEven(x int) bool { ret x % 2 == 0 }
fun isAny(x int) bool {
	if x < 0 { ret true }
	ret true
}
fun isNever(x int) bool {
	if x < 0 { ret false }
	ret false
}

fun dbl(x int) int { ret x * 2 }
fun ident(x int) int { ret x }
fun inc(x int) int { ret x + 1 }

fun isLong(s string) bool {
	if len(s) >= 3 { ret true }
	ret false
}
fun upperFirst(s string) string {
	if len(s) == 0 { ret "" }
	var c byte = s[0]
	if c >= 97 { if c <= 122 { c = c - 32 } }
	var r string = chr(c)
	for i := 1; i < len(s); i++ {
		r = r + chr(s[i])
	}
	ret r
}

fun main() int {
	var pass int = 0

	// Double positives, drop non-positives.
	var a []int = new(5) []int { -2, 3, -1, 4, 0 }
	var r1 []int = slices.FilterMapInt(a, isPos, dbl)
	if len(r1) == 2 { pass = pass + 1 }
	if r1[0] == 6 { pass = pass + 1 }
	if r1[1] == 8 { pass = pass + 1 }

	// Keep evens unchanged.
	var b []int = new(6) []int { 1, 2, 3, 4, 5, 6 }
	var r2 []int = slices.FilterMapInt(b, isEven, ident)
	if len(r2) == 3 { pass = pass + 1 }
	if r2[0] == 2 { pass = pass + 1 }
	if r2[1] == 4 { pass = pass + 1 }
	if r2[2] == 6 { pass = pass + 1 }

	// Always-drop → empty.
	var c []int = new(3) []int { 1, 2, 3 }
	var r3 []int = slices.FilterMapInt(c, isNever, dbl)
	if len(r3) == 0 { pass = pass + 1 }

	// Always-keep with increment.
	var d []int = new(3) []int { 1, 2, 3 }
	var r4 []int = slices.FilterMapInt(d, isAny, inc)
	if len(r4) == 3 { pass = pass + 1 }
	if r4[0] == 2 { pass = pass + 1 }
	if r4[2] == 4 { pass = pass + 1 }

	// Empty input.
	var empty []int = new(0) []int {}
	var r5 []int = slices.FilterMapInt(empty, isPos, dbl)
	if len(r5) == 0 { pass = pass + 1 }

	// FilterMapString — keep long, uppercase first byte.
	var sa []string = new(5) []string { "hi", "world", "no", "hello", "ok" }
	var rs1 []string = slices.FilterMapString(sa, isLong, upperFirst)
	if len(rs1) == 2 { pass = pass + 1 }
	if rs1[0] == "World" { pass = pass + 1 }
	if rs1[1] == "Hello" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
