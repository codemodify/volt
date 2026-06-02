package main
import "log"
import "slices"

// Positive test: slices.WindowInts / WindowStrings — overlapping
// sliding windows of `size` elements over a slice.

fun main() int {
	var pass int = 0

	// Window size 3 over [1, 2, 3, 4, 5] → 3 windows.
	var s1 []int = new(5) []int{1, 2, 3, 4, 5}
	var w1 [][]int = slices.WindowInts(s1, 3)
	if len(w1) == 3 { pass = pass + 1 }
	if w1[0][0] == 1 { pass = pass + 1 }
	if w1[0][2] == 3 { pass = pass + 1 }
	if w1[1][0] == 2 { pass = pass + 1 }
	if w1[2][2] == 5 { pass = pass + 1 }

	// Window size 1 = each element as a singleton.
	var s2 []int = new(3) []int{10, 20, 30}
	var w2 [][]int = slices.WindowInts(s2, 1)
	if len(w2) == 3 { pass = pass + 1 }
	if w2[1][0] == 20 { pass = pass + 1 }

	// Window size == len(s) → single window.
	var s3 []int = new(3) []int{1, 2, 3}
	var w3 [][]int = slices.WindowInts(s3, 3)
	if len(w3) == 1 { pass = pass + 1 }
	if w3[0][2] == 3 { pass = pass + 1 }

	// Window size > len(s) → empty.
	var s4 []int = new(2) []int{1, 2}
	var w4 [][]int = slices.WindowInts(s4, 3)
	if len(w4) == 0 { pass = pass + 1 }

	// Window size <= 0 → empty.
	var s5 []int = new(3) []int{1, 2, 3}
	var w5 [][]int = slices.WindowInts(s5, 0)
	if len(w5) == 0 { pass = pass + 1 }
	var w6 [][]int = slices.WindowInts(s5, -1)
	if len(w6) == 0 { pass = pass + 1 }

	// WindowStrings.
	var s7 []string = new(4) []string{"a", "b", "c", "d"}
	var w7 [][]string = slices.WindowStrings(s7, 2)
	if len(w7) == 3 { pass = pass + 1 }
	if w7[0][0] == "a" { pass = pass + 1 }
	if w7[2][1] == "d" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
