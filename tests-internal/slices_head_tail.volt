package main
import "log"
import "slices"

// Positive test: slices.HeadInts / TailInts / HeadStrings / TailStrings.

fun main() int {
	var pass int = 0

	// HeadInts standard.
	var s1 []int = new(5) []int{1, 2, 3, 4, 5}
	var h1 []int = slices.HeadInts(s1, 3)
	if len(h1) == 3 { pass = pass + 1 }
	if h1[0] == 1 { pass = pass + 1 }
	if h1[2] == 3 { pass = pass + 1 }

	// HeadInts: n > len → copy of s.
	var s2 []int = new(3) []int{10, 20, 30}
	var h2 []int = slices.HeadInts(s2, 10)
	if len(h2) == 3 { pass = pass + 1 }
	if h2[2] == 30 { pass = pass + 1 }

	// HeadInts: n <= 0 → empty.
	var s3 []int = new(3) []int{1, 2, 3}
	var h3 []int = slices.HeadInts(s3, 0)
	if len(h3) == 0 { pass = pass + 1 }
	var h4 []int = slices.HeadInts(s3, -1)
	if len(h4) == 0 { pass = pass + 1 }

	// TailInts standard.
	var s4 []int = new(5) []int{1, 2, 3, 4, 5}
	var t1 []int = slices.TailInts(s4, 2)
	if len(t1) == 2 { pass = pass + 1 }
	if t1[0] == 4 { pass = pass + 1 }
	if t1[1] == 5 { pass = pass + 1 }

	// TailInts: n > len → copy.
	var s5 []int = new(3) []int{10, 20, 30}
	var t2 []int = slices.TailInts(s5, 100)
	if len(t2) == 3 { pass = pass + 1 }
	if t2[0] == 10 { pass = pass + 1 }

	// TailInts: n <= 0 → empty.
	var s6 []int = new(3) []int{1, 2, 3}
	var t3 []int = slices.TailInts(s6, 0)
	if len(t3) == 0 { pass = pass + 1 }

	// HeadStrings.
	var s7 []string = new(4) []string{"a", "b", "c", "d"}
	var h5 []string = slices.HeadStrings(s7, 2)
	if len(h5) == 2 { pass = pass + 1 }
	if h5[1] == "b" { pass = pass + 1 }

	// TailStrings.
	var s8 []string = new(4) []string{"a", "b", "c", "d"}
	var t4 []string = slices.TailStrings(s8, 2)
	if len(t4) == 2 { pass = pass + 1 }
	if t4[0] == "c" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
