package main
import "log"
import "slices"

// Positive test: slices.SplitByInt + slices.SplitByString.

fun main() int {
	var pass int = 0

	// SplitByInt — basic.
	var s1 [][]int = slices.SplitByInt(new(7) []int { 1, 2, 0, 3, 4, 0, 5 }, 0)
	if len(s1) == 3 { pass = pass + 1 }
	if len(s1[0]) == 2 { pass = pass + 1 }
	if s1[0][0] == 1 { pass = pass + 1 }
	if s1[0][1] == 2 { pass = pass + 1 }
	if s1[1][0] == 3 { pass = pass + 1 }
	if s1[1][1] == 4 { pass = pass + 1 }
	if s1[2][0] == 5 { pass = pass + 1 }

	// SplitByInt — leading separator → empty leading sub-run.
	var s2 [][]int = slices.SplitByInt(new(4) []int { 0, 1, 2, 3 }, 0)
	if len(s2) == 2 { pass = pass + 1 }
	if len(s2[0]) == 0 { pass = pass + 1 }
	if s2[1][0] == 1 { pass = pass + 1 }

	// SplitByInt — trailing separator → empty trailing sub-run.
	var s3 [][]int = slices.SplitByInt(new(4) []int { 1, 2, 3, 0 }, 0)
	if len(s3) == 2 { pass = pass + 1 }
	if len(s3[1]) == 0 { pass = pass + 1 }
	if s3[0][2] == 3 { pass = pass + 1 }

	// SplitByInt — adjacent separators → empty between.
	var s4 [][]int = slices.SplitByInt(new(5) []int { 1, 0, 0, 2, 3 }, 0)
	if len(s4) == 3 { pass = pass + 1 }
	if len(s4[1]) == 0 { pass = pass + 1 }
	if s4[2][0] == 2 { pass = pass + 1 }

	// SplitByInt — no separator → whole slice as single piece.
	var s5 [][]int = slices.SplitByInt(new(3) []int { 1, 2, 3 }, 99)
	if len(s5) == 1 { pass = pass + 1 }
	if len(s5[0]) == 3 { pass = pass + 1 }

	// SplitByInt — empty.
	var s6 [][]int = slices.SplitByInt(new(0) []int {}, 0)
	if len(s6) == 1 { pass = pass + 1 }
	if len(s6[0]) == 0 { pass = pass + 1 }

	// SplitByString — basic.
	var t1 [][]string = slices.SplitByString(new(5) []string { "a", "b", "|", "c", "d" }, "|")
	if len(t1) == 2 { pass = pass + 1 }
	if t1[0][0] == "a" { pass = pass + 1 }
	if t1[1][1] == "d" { pass = pass + 1 }

	// SplitByString — no separator.
	var t2 [][]string = slices.SplitByString(new(2) []string { "a", "b" }, "z")
	if len(t2) == 1 { pass = pass + 1 }
	if t2[0][1] == "b" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 25 { ret 42 }
	ret 0
}
