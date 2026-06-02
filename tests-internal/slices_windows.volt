package main
import "log"
import "slices"

// Positive test: slices.WindowsInt + slices.WindowsString.

fun main() int {
	var pass int = 0

	// WindowsInt — basic k=2.
	var w1 [][]int = slices.WindowsInt(new(5) []int { 1, 2, 3, 4, 5 }, 2)
	if len(w1) == 4 { pass = pass + 1 }
	if w1[0][0] == 1 { pass = pass + 1 }
	if w1[0][1] == 2 { pass = pass + 1 }
	if w1[3][0] == 4 { pass = pass + 1 }
	if w1[3][1] == 5 { pass = pass + 1 }

	// WindowsInt — k=3 sliding window.
	var w2 [][]int = slices.WindowsInt(new(5) []int { 1, 2, 3, 4, 5 }, 3)
	if len(w2) == 3 { pass = pass + 1 }
	if w2[0][2] == 3 { pass = pass + 1 }
	if w2[2][0] == 3 { pass = pass + 1 }
	if w2[2][2] == 5 { pass = pass + 1 }

	// WindowsInt — k=1 (each element in its own window).
	var w3 [][]int = slices.WindowsInt(new(3) []int { 10, 20, 30 }, 1)
	if len(w3) == 3 { pass = pass + 1 }
	if w3[1][0] == 20 { pass = pass + 1 }

	// WindowsInt — k == len(s).
	var w4 [][]int = slices.WindowsInt(new(3) []int { 1, 2, 3 }, 3)
	if len(w4) == 1 { pass = pass + 1 }
	if w4[0][2] == 3 { pass = pass + 1 }

	// WindowsInt — k > len(s).
	var w5 [][]int = slices.WindowsInt(new(2) []int { 1, 2 }, 5)
	if len(w5) == 0 { pass = pass + 1 }

	// WindowsInt — k <= 0.
	var w6 [][]int = slices.WindowsInt(new(3) []int { 1, 2, 3 }, 0)
	if len(w6) == 0 { pass = pass + 1 }
	var w7 [][]int = slices.WindowsInt(new(3) []int { 1, 2, 3 }, -1)
	if len(w7) == 0 { pass = pass + 1 }

	// WindowsInt — empty input.
	var w8 [][]int = slices.WindowsInt(new(0) []int {}, 2)
	if len(w8) == 0 { pass = pass + 1 }

	// WindowsString — basic.
	var ws1 [][]string = slices.WindowsString(new(4) []string { "a", "b", "c", "d" }, 2)
	if len(ws1) == 3 { pass = pass + 1 }
	if ws1[0][0] == "a" { pass = pass + 1 }
	if ws1[0][1] == "b" { pass = pass + 1 }
	if ws1[2][1] == "d" { pass = pass + 1 }

	// WindowsString — k > len.
	var ws2 [][]string = slices.WindowsString(new(2) []string { "x", "y" }, 5)
	if len(ws2) == 0 { pass = pass + 1 }

	// WindowsString — empty input.
	var ws3 [][]string = slices.WindowsString(new(0) []string {}, 1)
	if len(ws3) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
