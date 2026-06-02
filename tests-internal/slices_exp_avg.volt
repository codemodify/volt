package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Basic: alpha100=50, first output equals s[0], next outputs
	// blend 50/50.
	var s1 []int = new(4) []int {0, 100, 0, 100}
	var r1 []int = slices.ExpAvgInt(s1, 50)
	// out[0]=0; out[1]=(50*100 + 50*0)/100 = 50;
	// out[2]=(50*0 + 50*50)/100 = 25; out[3]=(50*100 + 50*25)/100 = 62
	if r1[0] == 0 { pass = pass + 1 }
	if r1[1] == 50 { pass = pass + 1 }
	if r1[2] == 25 { pass = pass + 1 }
	if r1[3] == 62 { pass = pass + 1 }

	// alpha100=100: pure new sample, out == s.
	var s2 []int = new(3) []int {10, 20, 30}
	var r2 []int = slices.ExpAvgInt(s2, 100)
	if r2[0] == 10 { pass = pass + 1 }
	if r2[1] == 20 { pass = pass + 1 }
	if r2[2] == 30 { pass = pass + 1 }

	// alpha100=0: stays at s[0] forever.
	var s3 []int = new(4) []int {7, 999, -50, 100}
	var r3 []int = slices.ExpAvgInt(s3, 0)
	if r3[0] == 7 { pass = pass + 1 }
	if r3[1] == 7 { pass = pass + 1 }
	if r3[2] == 7 { pass = pass + 1 }
	if r3[3] == 7 { pass = pass + 1 }

	// Empty input.
	var s4 []int = new(0) []int {}
	var r4 []int = slices.ExpAvgInt(s4, 30)
	if len(r4) == 0 { pass = pass + 1 }

	// Single-element.
	var s5 []int = new(1) []int {42}
	var r5 []int = slices.ExpAvgInt(s5, 30)
	if len(r5) == 1 { pass = pass + 1 }
	if r5[0] == 42 { pass = pass + 1 }

	// Out-of-range alpha clamps.
	var s6 []int = new(2) []int {10, 20}
	var r6 []int = slices.ExpAvgInt(s6, 200)
	// clamped to 100; out[1] = (100*20 + 0*10)/100 = 20
	if r6[1] == 20 { pass = pass + 1 }
	var r6b []int = slices.ExpAvgInt(s6, -50)
	// clamped to 0; out[1] = 10
	if r6b[1] == 10 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
