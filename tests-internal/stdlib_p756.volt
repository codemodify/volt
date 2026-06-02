package main
import "log"
import "slices"
import "strings"

fun main() int {
	var pass int = 0

	// CommaInt basics
	if strings.CommaInt(0) == "0" { pass = pass + 1 }
	if strings.CommaInt(42) == "42" { pass = pass + 1 }
	if strings.CommaInt(999) == "999" { pass = pass + 1 }
	if strings.CommaInt(1000) == "1,000" { pass = pass + 1 }
	if strings.CommaInt(12345) == "12,345" { pass = pass + 1 }
	if strings.CommaInt(123456) == "123,456" { pass = pass + 1 }
	if strings.CommaInt(1234567) == "1,234,567" { pass = pass + 1 }
	if strings.CommaInt(1000000000) == "1,000,000,000" { pass = pass + 1 }
	if strings.CommaInt(-50000) == "-50,000" { pass = pass + 1 }
	if strings.CommaInt(-1) == "-1" { pass = pass + 1 }

	// MovingMedianInt basics
	// [1, 5, 2, 100, 3] with k=3:
	// pos 0: window [1] → median 1
	// pos 1: window [1, 5] → median 1 (nearest-rank p50 of sorted [1,5] is rank 1 → 1)
	// pos 2: window [1, 5, 2] sorted [1,2,5] → median 2
	// pos 3: window [5, 2, 100] sorted [2,5,100] → median 5
	// pos 4: window [2, 100, 3] sorted [2,3,100] → median 3
	var s1 []int = new(5) []int {1, 5, 2, 100, 3}
	var r1 []int = slices.MovingMedianInt(s1, 3)
	if len(r1) == 5 { pass = pass + 1 }
	if r1[2] == 2 { pass = pass + 1 }
	if r1[3] == 5 { pass = pass + 1 }
	if r1[4] == 3 { pass = pass + 1 }

	// Empty input
	var s2 []int = new(0) []int {}
	var r2 []int = slices.MovingMedianInt(s2, 3)
	if len(r2) == 0 { pass = pass + 1 }

	// k = 1: each element is its own median
	var s3 []int = new(4) []int {7, 3, 9, 1}
	var r3 []int = slices.MovingMedianInt(s3, 1)
	if r3[0] == 7 { pass = pass + 1 }
	if r3[1] == 3 { pass = pass + 1 }
	if r3[2] == 9 { pass = pass + 1 }
	if r3[3] == 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
