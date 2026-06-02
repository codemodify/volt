// Pass 757 stdlib additions: strings.WrapAt / JustifyLeft/Right/Center
// + slices.WindowedInt / PairsInt / DeltasInt / CumSumInt.
package main
import "log"
import "strings"
import "slices"

fun main() int {
	var pass int = 0

	// WrapAt: simple 10-column wrap.
	var w1 string = strings.WrapAt("the quick brown fox jumps over the lazy dog", 10)
	// Expected: greedy break at word boundaries.
	if strings.Contains(w1, "\n") { pass = pass + 1 }
	if strings.HasPrefix(w1, "the quick") { pass = pass + 1 }
	// No line should exceed 10 chars.
	var lines []string = strings.Lines(w1)
	var ok bool = true
	for i := 0; i < len(lines); i++ {
		if len(lines[i]) > 10 { ok = false }
	}
	if ok { pass = pass + 1 }

	// Width 0 → no wrap.
	if strings.WrapAt("hello world", 0) == "hello world" { pass = pass + 1 }
	// Empty input → empty result.
	if strings.WrapAt("", 10) == "" { pass = pass + 1 }
	// Single short word fits on one line.
	if strings.WrapAt("hi", 80) == "hi" { pass = pass + 1 }

	// Justify variants.
	if strings.JustifyLeft("hi", 5) == "hi   " { pass = pass + 1 }
	if strings.JustifyRight("hi", 5) == "   hi" { pass = pass + 1 }
	if strings.JustifyCenter("hi", 6) == "  hi  " { pass = pass + 1 }
	if strings.JustifyCenter("hi", 5) == " hi  " { pass = pass + 1 }  // odd: extra on right
	// Already-wide: unchanged.
	if strings.JustifyLeft("hello", 3) == "hello" { pass = pass + 1 }

	// WindowedInt: 3-windows over [1,2,3,4,5] → [[1,2,3],[2,3,4],[3,4,5]]
	var s1 []int = new(5) []int {1, 2, 3, 4, 5}
	var win [][]int = slices.WindowedInt(s1, 3)
	if len(win) == 3 { pass = pass + 1 }
	if win[0][0] == 1 && win[0][1] == 2 && win[0][2] == 3 { pass = pass + 1 }
	if win[2][0] == 3 && win[2][1] == 4 && win[2][2] == 5 { pass = pass + 1 }
	// Too-large k → empty.
	var win2 [][]int = slices.WindowedInt(s1, 10)
	if len(win2) == 0 { pass = pass + 1 }

	// PairsInt over [10,20,30,40] → [10,20, 20,30, 30,40]
	var s2 []int = new(4) []int {10, 20, 30, 40}
	var p []int = slices.PairsInt(s2)
	if len(p) == 6 { pass = pass + 1 }
	if p[0] == 10 && p[1] == 20 { pass = pass + 1 }
	if p[4] == 30 && p[5] == 40 { pass = pass + 1 }

	// DeltasInt over [10,20,15,40] → [10,-5,25]
	var s3 []int = new(4) []int {10, 20, 15, 40}
	var d []int = slices.DeltasInt(s3)
	if len(d) == 3 { pass = pass + 1 }
	if d[0] == 10 && d[1] == -5 && d[2] == 25 { pass = pass + 1 }

	// CumSumInt over [1,2,3,4] → [1,3,6,10]
	var s4 []int = new(4) []int {1, 2, 3, 4}
	var cs []int = slices.CumSumInt(s4)
	if cs[0] == 1 && cs[1] == 3 && cs[2] == 6 && cs[3] == 10 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
