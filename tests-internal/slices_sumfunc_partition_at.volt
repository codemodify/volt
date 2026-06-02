package main
import "log"
import "slices"

// Positive test: slices.SumIntFunc + SumStringFunc + PartitionAtInt + PartitionAtString.

fun square(x int) int { ret x * x }
fun double(x int) int { ret x * 2 }
fun strLen(s string) int { ret len(s) }

fun main() int {
	var pass int = 0

	// SumIntFunc — sum of squares.
	var a []int = new(4) []int{1, 2, 3, 4}
	if slices.SumIntFunc(a, square) == 30 { pass = pass + 1 }   // 1+4+9+16

	// Sum of doubles.
	if slices.SumIntFunc(a, double) == 20 { pass = pass + 1 }   // 2+4+6+8

	// Empty.
	var e []int = new(0) []int{}
	if slices.SumIntFunc(e, square) == 0 { pass = pass + 1 }

	// Single.
	var sa []int = new(1) []int{5}
	if slices.SumIntFunc(sa, square) == 25 { pass = pass + 1 }

	// SumStringFunc — sum of lengths.
	var s []string = new(3) []string{"a", "bb", "ccc"}
	if slices.SumStringFunc(s, strLen) == 6 { pass = pass + 1 }

	// Empty.
	var se []string = new(0) []string{}
	if slices.SumStringFunc(se, strLen) == 0 { pass = pass + 1 }

	// PartitionAtInt — basic.
	var b []int = new(5) []int{10, 20, 30, 40, 50}
	var left []int = new(0) []int{}
	var right []int = new(0) []int{}
	left, right = slices.PartitionAtInt(b, 2)
	if len(left) == 2 { pass = pass + 1 }
	if left[0] == 10 { pass = pass + 1 }
	if left[1] == 20 { pass = pass + 1 }
	if len(right) == 3 { pass = pass + 1 }
	if right[0] == 30 { pass = pass + 1 }
	if right[2] == 50 { pass = pass + 1 }

	// PartitionAtInt at 0 → empty left.
	left, right = slices.PartitionAtInt(b, 0)
	if len(left) == 0 { pass = pass + 1 }
	if len(right) == 5 { pass = pass + 1 }

	// PartitionAtInt at n → empty right.
	left, right = slices.PartitionAtInt(b, 5)
	if len(left) == 5 { pass = pass + 1 }
	if len(right) == 0 { pass = pass + 1 }

	// Negative index → clamped to 0.
	left, right = slices.PartitionAtInt(b, -1)
	if len(left) == 0 { pass = pass + 1 }
	if len(right) == 5 { pass = pass + 1 }

	// Index past end → clamped to n.
	left, right = slices.PartitionAtInt(b, 100)
	if len(left) == 5 { pass = pass + 1 }
	if len(right) == 0 { pass = pass + 1 }

	// Empty input.
	var em []int = new(0) []int{}
	left, right = slices.PartitionAtInt(em, 3)
	if len(left) == 0 { pass = pass + 1 }
	if len(right) == 0 { pass = pass + 1 }

	// PartitionAtString.
	var ss []string = new(4) []string{"a", "b", "c", "d"}
	var sLeft []string = new(0) []string{}
	var sRight []string = new(0) []string{}
	sLeft, sRight = slices.PartitionAtString(ss, 2)
	if len(sLeft) == 2 { pass = pass + 1 }
	if sLeft[0] == "a" { pass = pass + 1 }
	if len(sRight) == 2 { pass = pass + 1 }
	if sRight[0] == "c" { pass = pass + 1 }
	if sRight[1] == "d" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
