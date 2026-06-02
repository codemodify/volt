package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	var out []int = new(0) []int {}
	var err error = nil

	// SplitToInts — basic.
	out, err = strings.SplitToInts("1,2,3,4", ",")
	if err == nil { pass = pass + 1 }
	if len(out) == 4 { pass = pass + 1 }
	if out[0] == 1 { pass = pass + 1 }
	if out[3] == 4 { pass = pass + 1 }

	// SplitToInts — negative values.
	out, err = strings.SplitToInts("-1,0,1", ",")
	if err == nil { pass = pass + 1 }
	if out[0] == -1 { pass = pass + 1 }

	// SplitToInts — single value.
	out, err = strings.SplitToInts("42", ",")
	if err == nil { pass = pass + 1 }
	if out[0] == 42 { pass = pass + 1 }

	// SplitToInts — parse error.
	out, err = strings.SplitToInts("1,bad,3", ",")
	if err != nil { pass = pass + 1 }
	if len(out) == 0 { pass = pass + 1 }   // error path returns empty

	// SplitToInts — different separator.
	out, err = strings.SplitToInts("10|20|30", "|")
	if err == nil { pass = pass + 1 }
	if out[1] == 20 { pass = pass + 1 }

	// SplitToIntsLossy — skips bad pieces.
	var lossy []int = strings.SplitToIntsLossy("1,bad,3,oops,5", ",")
	if len(lossy) == 3 { pass = pass + 1 }
	if lossy[0] == 1 { pass = pass + 1 }
	if lossy[1] == 3 { pass = pass + 1 }
	if lossy[2] == 5 { pass = pass + 1 }

	// SplitToIntsLossy — all bad.
	var allBad []int = strings.SplitToIntsLossy("a,b,c", ",")
	if len(allBad) == 0 { pass = pass + 1 }

	// SplitToIntsLossy — all good.
	var allGood []int = strings.SplitToIntsLossy("1,2,3", ",")
	if len(allGood) == 3 { pass = pass + 1 }

	// Roundtrip: SplitToInts(JoinInts(s)) == s.
	var orig []int = new(3) []int { 7, 8, 9 }
	out, err = strings.SplitToInts(strings.JoinInts(orig, ","), ",")
	if err == nil { pass = pass + 1 }
	if out[0] == 7 { pass = pass + 1 }
	if out[2] == 9 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
