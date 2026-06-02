package main
import "log"
import "slices"

// Positive test: slices.JoinByInt + slices.JoinByString.

fun main() int {
	var pass int = 0

	// JoinByInt — basic.
	var parts1 [][]int = new(3) [][]int { new(2) []int { 1, 2 }, new(2) []int { 3, 4 }, new(1) []int { 5 } }
	var j1 []int = slices.JoinByInt(parts1, 0)
	if len(j1) == 7 { pass = pass + 1 }   // 2+2+1 + 2 seps
	if j1[0] == 1 { pass = pass + 1 }
	if j1[1] == 2 { pass = pass + 1 }
	if j1[2] == 0 { pass = pass + 1 }
	if j1[3] == 3 { pass = pass + 1 }
	if j1[4] == 4 { pass = pass + 1 }
	if j1[5] == 0 { pass = pass + 1 }
	if j1[6] == 5 { pass = pass + 1 }

	// JoinByInt — single part (no separator inserted).
	var parts2 [][]int = new(1) [][]int { new(3) []int { 1, 2, 3 } }
	var j2 []int = slices.JoinByInt(parts2, 99)
	if len(j2) == 3 { pass = pass + 1 }
	if j2[2] == 3 { pass = pass + 1 }

	// JoinByInt — empty parts.
	var parts3 [][]int = new(0) [][]int {}
	var j3 []int = slices.JoinByInt(parts3, 0)
	if len(j3) == 0 { pass = pass + 1 }

	// JoinByInt — empty sub-runs preserve separators.
	var parts4 [][]int = new(3) [][]int { new(0) []int {}, new(0) []int {}, new(0) []int {} }
	var j4 []int = slices.JoinByInt(parts4, 5)
	if len(j4) == 2 { pass = pass + 1 }
	if j4[0] == 5 { pass = pass + 1 }
	if j4[1] == 5 { pass = pass + 1 }

	// Identity: Join(Split(s, sep), sep) == s.
	var orig []int = new(7) []int { 1, 2, 0, 3, 4, 0, 5 }
	var splitParts [][]int = slices.SplitByInt(orig, 0)
	var rejoined []int = slices.JoinByInt(splitParts, 0)
	if len(rejoined) == 7 { pass = pass + 1 }
	if rejoined[0] == 1 { pass = pass + 1 }
	if rejoined[2] == 0 { pass = pass + 1 }
	if rejoined[6] == 5 { pass = pass + 1 }

	// JoinByString — basic.
	var sp1 [][]string = new(2) [][]string { new(2) []string { "a", "b" }, new(1) []string { "c" } }
	var sj1 []string = slices.JoinByString(sp1, "|")
	if len(sj1) == 4 { pass = pass + 1 }
	if sj1[0] == "a" { pass = pass + 1 }
	if sj1[2] == "|" { pass = pass + 1 }
	if sj1[3] == "c" { pass = pass + 1 }

	// JoinByString — empty.
	var sp2 [][]string = new(0) [][]string {}
	var sj2 []string = slices.JoinByString(sp2, "x")
	if len(sj2) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
