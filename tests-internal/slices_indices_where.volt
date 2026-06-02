package main
import "log"
import "slices"

fun isEven(x int) bool { ret x % 2 == 0 }
fun isNeg(x int) bool { ret x < 0 }
fun isZero(x int) bool { ret x == 0 }
fun lenGt3(s string) bool {
	if len(s) > 3 { ret true }
	ret false
}
fun startsWithA(s string) bool {
	if len(s) == 0 { ret false }
	if s[0] == 97 { ret true }
	ret false
}

fun main() int {
	var pass int = 0

	// IndicesWhereInt — basic even-positions.
	var a []int = new(6) []int { 1, 2, 3, 4, 5, 6 }
	var r1 []int = slices.IndicesWhereInt(a, isEven)
	if len(r1) == 3 { pass = pass + 1 }
	if r1[0] == 1 { pass = pass + 1 }     // 2 at idx 1
	if r1[1] == 3 { pass = pass + 1 }     // 4 at idx 3
	if r1[2] == 5 { pass = pass + 1 }     // 6 at idx 5

	// IndicesWhereInt — no match → empty.
	var b []int = new(3) []int { 1, 3, 5 }
	var r2 []int = slices.IndicesWhereInt(b, isEven)
	if len(r2) == 0 { pass = pass + 1 }

	// IndicesWhereInt — all match.
	var c []int = new(4) []int { 2, 4, 6, 8 }
	var r3 []int = slices.IndicesWhereInt(c, isEven)
	if len(r3) == 4 { pass = pass + 1 }
	if r3[0] == 0 { pass = pass + 1 }
	if r3[3] == 3 { pass = pass + 1 }

	// IndicesWhereInt — negatives.
	var d []int = new(6) []int { 1, -2, 3, -4, 5, -6 }
	var r4 []int = slices.IndicesWhereInt(d, isNeg)
	if len(r4) == 3 { pass = pass + 1 }
	if r4[0] == 1 { pass = pass + 1 }
	if r4[2] == 5 { pass = pass + 1 }

	// IndicesWhereInt — empty input.
	var empty []int = new(0) []int {}
	var r5 []int = slices.IndicesWhereInt(empty, isEven)
	if len(r5) == 0 { pass = pass + 1 }

	// IndicesWhereInt — zeros.
	var e []int = new(5) []int { 1, 0, 2, 0, 3 }
	var r6 []int = slices.IndicesWhereInt(e, isZero)
	if len(r6) == 2 { pass = pass + 1 }
	if r6[0] == 1 { pass = pass + 1 }
	if r6[1] == 3 { pass = pass + 1 }

	// IndicesWhereString — by length.
	var sa []string = new(5) []string { "a", "longer", "no", "abcd", "hi" }
	var rs1 []int = slices.IndicesWhereString(sa, lenGt3)
	if len(rs1) == 2 { pass = pass + 1 }
	if rs1[0] == 1 { pass = pass + 1 }
	if rs1[1] == 3 { pass = pass + 1 }

	// IndicesWhereString — startsWithA.
	var sb []string = new(4) []string { "apple", "banana", "avocado", "cherry" }
	var rs2 []int = slices.IndicesWhereString(sb, startsWithA)
	if len(rs2) == 2 { pass = pass + 1 }
	if rs2[0] == 0 { pass = pass + 1 }
	if rs2[1] == 2 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
