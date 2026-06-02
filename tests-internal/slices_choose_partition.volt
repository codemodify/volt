package main
import "log"
import "slices"

// Positive test: slices.ChooseInt / ChooseString / PartitionInts /
// PartitionStrings.

fun isEven(x int) bool { ret (x % 2) == 0 }
fun isLong(s string) bool { ret len(s) >= 3 }

fun main() int {
	var pass int = 0

	// ChooseInt: every choice is a valid element.
	var s1 []int = new(5) []int{10, 20, 30, 40, 50}
	var allIn bool = true
	for i := 0; i < 50; i++ {
		var v int = slices.ChooseInt(s1)
		if !slices.ContainsInt(s1, v) { allIn = false }
	}
	if allIn { pass = pass + 1 }

	// ChooseInt: empty slice → 0.
	var empty []int = new(0) []int{}
	if slices.ChooseInt(empty) == 0 { pass = pass + 1 }

	// ChooseString.
	var s2 []string = new(3) []string{"alpha", "beta", "gamma"}
	var allInStr bool = true
	for i := 0; i < 30; i++ {
		var v string = slices.ChooseString(s2)
		if !slices.ContainsString(s2, v) { allInStr = false }
	}
	if allInStr { pass = pass + 1 }

	// ChooseString: empty → "".
	var emptyS []string = new(0) []string{}
	if slices.ChooseString(emptyS) == "" { pass = pass + 1 }

	// PartitionInts: even/odd split.
	var s3 []int = new(6) []int{1, 2, 3, 4, 5, 6}
	var ev []int = new(0) []int{}
	var od []int = new(0) []int{}
	ev, od = slices.PartitionInts(s3, isEven)
	if len(ev) == 3 { pass = pass + 1 }
	if len(od) == 3 { pass = pass + 1 }
	if ev[0] == 2 { pass = pass + 1 }
	if ev[2] == 6 { pass = pass + 1 }
	if od[0] == 1 { pass = pass + 1 }
	if od[2] == 5 { pass = pass + 1 }

	// PartitionInts: all match.
	var s4 []int = new(3) []int{2, 4, 6}
	var ma []int = new(0) []int{}
	var re []int = new(0) []int{}
	ma, re = slices.PartitionInts(s4, isEven)
	if len(ma) == 3 { pass = pass + 1 }
	if len(re) == 0 { pass = pass + 1 }

	// PartitionInts: none match.
	var s5 []int = new(3) []int{1, 3, 5}
	var ma2 []int = new(0) []int{}
	var re2 []int = new(0) []int{}
	ma2, re2 = slices.PartitionInts(s5, isEven)
	if len(ma2) == 0 { pass = pass + 1 }
	if len(re2) == 3 { pass = pass + 1 }

	// PartitionStrings.
	var s6 []string = new(5) []string{"a", "bcd", "e", "fgh", "i"}
	var mlong []string = new(0) []string{}
	var mshort []string = new(0) []string{}
	mlong, mshort = slices.PartitionStrings(s6, isLong)
	if len(mlong) == 2 { pass = pass + 1 }
	if mlong[0] == "bcd" { pass = pass + 1 }
	if len(mshort) == 3 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
