package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty / degenerate.
	var e []int = new(0) []int {}
	var r1 []int = slices.MovingSumInt(e, 3)
	if len(r1) == 0 { pass = pass + 1 }

	var s0 []int = new(3) []int { 1, 2, 3 }
	var r2 []int = slices.MovingSumInt(s0, 0)
	if len(r2) == 0 { pass = pass + 1 }

	var s0b []int = new(3) []int { 1, 2, 3 }
	var r3 []int = slices.MovingSumInt(s0b, -2)
	if len(r3) == 0 { pass = pass + 1 }

	// n < k → empty.
	var s0c []int = new(3) []int { 1, 2, 3 }
	var r4 []int = slices.MovingSumInt(s0c, 5)
	if len(r4) == 0 { pass = pass + 1 }

	// k == 1 → identity.
	var s1 []int = new(4) []int { 5, 7, 11, 13 }
	var r5 []int = slices.MovingSumInt(s1, 1)
	if len(r5) == 4 { pass = pass + 1 }
	if r5[0] == 5 { pass = pass + 1 }
	if r5[3] == 13 { pass = pass + 1 }

	// k == n → single window = sum of all.
	var s2 []int = new(4) []int { 5, 7, 11, 13 }
	var r6 []int = slices.MovingSumInt(s2, 4)
	if len(r6) == 1 { pass = pass + 1 }
	if r6[0] == 36 { pass = pass + 1 }

	// Window of 3 on [1..6].
	var s3 []int = new(6) []int { 1, 2, 3, 4, 5, 6 }
	var r7 []int = slices.MovingSumInt(s3, 3)
	// Windows: [1,2,3]=6, [2,3,4]=9, [3,4,5]=12, [4,5,6]=15
	if len(r7) == 4 { pass = pass + 1 }
	if r7[0] == 6 { pass = pass + 1 }
	if r7[1] == 9 { pass = pass + 1 }
	if r7[2] == 12 { pass = pass + 1 }
	if r7[3] == 15 { pass = pass + 1 }

	// MovingMin.
	var s4 []int = new(7) []int { 5, 3, 8, 1, 4, 9, 2 }
	var r8 []int = slices.MovingMinInt(s4, 3)
	// Windows: [5,3,8]=3, [3,8,1]=1, [8,1,4]=1, [1,4,9]=1, [4,9,2]=2
	if len(r8) == 5 { pass = pass + 1 }
	if r8[0] == 3 { pass = pass + 1 }
	if r8[1] == 1 { pass = pass + 1 }
	if r8[2] == 1 { pass = pass + 1 }
	if r8[3] == 1 { pass = pass + 1 }
	if r8[4] == 2 { pass = pass + 1 }

	// MovingMax.
	var s5 []int = new(7) []int { 5, 3, 8, 1, 4, 9, 2 }
	var r9 []int = slices.MovingMaxInt(s5, 3)
	// Windows: [5,3,8]=8, [3,8,1]=8, [8,1,4]=8, [1,4,9]=9, [4,9,2]=9
	if len(r9) == 5 { pass = pass + 1 }
	if r9[0] == 8 { pass = pass + 1 }
	if r9[1] == 8 { pass = pass + 1 }
	if r9[2] == 8 { pass = pass + 1 }
	if r9[3] == 9 { pass = pass + 1 }
	if r9[4] == 9 { pass = pass + 1 }

	// k == n for Min/Max → single window.
	var s6 []int = new(4) []int { 3, 1, 4, 1 }
	var r10 []int = slices.MovingMinInt(s6, 4)
	if len(r10) == 1 { pass = pass + 1 }
	if r10[0] == 1 { pass = pass + 1 }

	var s7 []int = new(4) []int { 3, 1, 4, 1 }
	var r11 []int = slices.MovingMaxInt(s7, 4)
	if r11[0] == 4 { pass = pass + 1 }

	// Cross-property: MovingMin <= MovingAvg <= MovingMax for each window.
	var s8 []int = new(5) []int { 10, 20, 30, 40, 50 }
	var s8b []int = new(5) []int { 10, 20, 30, 40, 50 }
	var s8c []int = new(5) []int { 10, 20, 30, 40, 50 }
	var mn []int = slices.MovingMinInt(s8, 2)
	var mx []int = slices.MovingMaxInt(s8b, 2)
	var av []int = slices.MovingAverageInt(s8c, 2)
	// Each window: min <= avg <= max
	if mn[0] <= av[0] { pass = pass + 1 }
	if av[0] <= mx[0] { pass = pass + 1 }
	if mn[3] <= av[3] { pass = pass + 1 }
	if av[3] <= mx[3] { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 33 { ret 42 }
	ret 0
}
