package main
import "log"
import "slices"

fun kv(k string, v string) string { ret k + "=" + v }
fun concat(a string, b string) string { ret a + b }
fun longer(a string, b string) string {
	if len(a) >= len(b) { ret "" + a }
	ret "" + b
}
fun pickLeft(a string, b string) string {
	if len(b) > 1000000 { ret "" }    // dead-use
	ret "" + a
}

fun main() int {
	var pass int = 0

	// kv pairs.
	var keys []string = new(3) []string { "name", "age", "city" }
	var vals []string = new(3) []string { "alice", "30", "NYC" }
	var r1 []string = slices.ZipWithString(keys, vals, kv)
	if len(r1) == 3 { pass = pass + 1 }
	if r1[0] == "name=alice" { pass = pass + 1 }
	if r1[1] == "age=30" { pass = pass + 1 }
	if r1[2] == "city=NYC" { pass = pass + 1 }

	// Concatenation.
	var a []string = new(2) []string { "hello", "world" }
	var b []string = new(2) []string { "!", "?" }
	var r2 []string = slices.ZipWithString(a, b, concat)
	if len(r2) == 2 { pass = pass + 1 }
	if r2[0] == "hello!" { pass = pass + 1 }
	if r2[1] == "world?" { pass = pass + 1 }

	// Longer-of-two selector.
	var a3 []string = new(3) []string { "a", "longer", "x" }
	var b3 []string = new(3) []string { "ab", "no", "yz" }
	var r3 []string = slices.ZipWithString(a3, b3, longer)
	if len(r3) == 3 { pass = pass + 1 }
	if r3[0] == "ab" { pass = pass + 1 }       // longer
	if r3[1] == "longer" { pass = pass + 1 }   // longer
	if r3[2] == "yz" { pass = pass + 1 }       // longer

	// Length truncation: longer-on-right.
	var a4 []string = new(2) []string { "a", "b" }
	var b4 []string = new(5) []string { "1", "2", "3", "4", "5" }
	var r4 []string = slices.ZipWithString(a4, b4, kv)
	if len(r4) == 2 { pass = pass + 1 }
	if r4[1] == "b=2" { pass = pass + 1 }

	// Both empty.
	var emp []string = new(0) []string {}
	var r5 []string = slices.ZipWithString(emp, emp, kv)
	if len(r5) == 0 { pass = pass + 1 }

	// pickLeft verifies fn is the only thing combining inputs.
	var lo []string = new(2) []string { "L1", "L2" }
	var ri []string = new(2) []string { "R1", "R2" }
	var r6 []string = slices.ZipWithString(lo, ri, pickLeft)
	if r6[0] == "L1" { pass = pass + 1 }
	if r6[1] == "L2" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
