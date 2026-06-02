package main
import "log"
import "slices"

// Positive test: slices.SampleInts / SampleStrings — random sample
// of k elements without replacement.

fun main() int {
	var pass int = 0

	// Sample k=3 from [1..10]. All elements must come from source.
	var src []int = new(10) []int{1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
	var allFromSrc bool = true
	for trial := 0; trial < 20; trial++ {
		var sample []int = slices.SampleInts(src, 3)
		if len(sample) != 3 { allFromSrc = false }
		for i := 0; i < 3; i++ {
			if !slices.ContainsInt(src, sample[i]) { allFromSrc = false }
		}
	}
	if allFromSrc { pass = pass + 1 }

	// k > len(s) returns a shuffled copy (length = len(s)).
	var s2 []int = new(3) []int{10, 20, 30}
	var samp2 []int = slices.SampleInts(s2, 100)
	if len(samp2) == 3 { pass = pass + 1 }
	// Multiset preservation.
	var setOK bool = true
	if !slices.ContainsInt(samp2, 10) { setOK = false }
	if !slices.ContainsInt(samp2, 20) { setOK = false }
	if !slices.ContainsInt(samp2, 30) { setOK = false }
	if setOK { pass = pass + 1 }

	// k == 0 → empty.
	var s3 []int = new(5) []int{1, 2, 3, 4, 5}
	var samp3 []int = slices.SampleInts(s3, 0)
	if len(samp3) == 0 { pass = pass + 1 }

	// k < 0 → empty.
	var s4 []int = new(5) []int{1, 2, 3, 4, 5}
	var samp4 []int = slices.SampleInts(s4, -1)
	if len(samp4) == 0 { pass = pass + 1 }

	// Empty source.
	var s5 []int = new(0) []int{}
	var samp5 []int = slices.SampleInts(s5, 5)
	if len(samp5) == 0 { pass = pass + 1 }

	// Without-replacement: sample of size n from n distinct elements
	// should contain n distinct elements (no duplicates).
	var src2 []int = new(5) []int{1, 2, 3, 4, 5}
	var samp6 []int = slices.SampleInts(src2, 5)
	var distinct bool = true
	for i := 0; i < 5; i++ {
		for j := i + 1; j < 5; j++ {
			if samp6[i] == samp6[j] { distinct = false }
		}
	}
	if distinct { pass = pass + 1 }

	// SampleStrings.
	var s7 []string = new(4) []string{"a", "b", "c", "d"}
	var samp7 []string = slices.SampleStrings(s7, 2)
	if len(samp7) == 2 { pass = pass + 1 }
	if slices.ContainsString(s7, samp7[0]) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 9 { ret 42 }
	ret 0
}
