package main
import "log"
import "slices"
import "math"

// Positive test: slices.WindowedSumInt + math.LogIntBase.

fun main() int {
	var pass int = 0

	// WindowedSumInt basic.
	var a []int = new(5) []int{1, 2, 3, 4, 5}
	var w []int = slices.WindowedSumInt(a, 3)
	if len(w) == 3 { pass = pass + 1 }
	if w[0] == 6 { pass = pass + 1 }   // 1+2+3
	if w[1] == 9 { pass = pass + 1 }   // 2+3+4
	if w[2] == 12 { pass = pass + 1 }  // 3+4+5

	// k=1 → identity.
	var w1 []int = slices.WindowedSumInt(a, 1)
	if len(w1) == 5 { pass = pass + 1 }
	if w1[0] == 1 { pass = pass + 1 }
	if w1[4] == 5 { pass = pass + 1 }

	// k=n → single sum.
	var wn []int = slices.WindowedSumInt(a, 5)
	if len(wn) == 1 { pass = pass + 1 }
	if wn[0] == 15 { pass = pass + 1 }

	// k>n → empty.
	if len(slices.WindowedSumInt(a, 10)) == 0 { pass = pass + 1 }

	// k=0 / k<0.
	if len(slices.WindowedSumInt(a, 0)) == 0 { pass = pass + 1 }
	if len(slices.WindowedSumInt(a, -1)) == 0 { pass = pass + 1 }

	// Empty slice.
	var e []int = new(0) []int{}
	if len(slices.WindowedSumInt(e, 3)) == 0 { pass = pass + 1 }

	// With negatives.
	var n []int = new(4) []int{5, -2, 3, -1}
	var wn2 []int = slices.WindowedSumInt(n, 2)
	if wn2[0] == 3 { pass = pass + 1 }    // 5+(-2)
	if wn2[1] == 1 { pass = pass + 1 }    // -2+3
	if wn2[2] == 2 { pass = pass + 1 }    // 3+(-1)

	// LogIntBase basic.
	if math.LogIntBase(1, 2) == 0 { pass = pass + 1 }
	if math.LogIntBase(2, 2) == 1 { pass = pass + 1 }
	if math.LogIntBase(3, 2) == 1 { pass = pass + 1 }
	if math.LogIntBase(4, 2) == 2 { pass = pass + 1 }
	if math.LogIntBase(7, 2) == 2 { pass = pass + 1 }
	if math.LogIntBase(8, 2) == 3 { pass = pass + 1 }
	if math.LogIntBase(1024, 2) == 10 { pass = pass + 1 }

	// Base 10.
	if math.LogIntBase(1, 10) == 0 { pass = pass + 1 }
	if math.LogIntBase(9, 10) == 0 { pass = pass + 1 }
	if math.LogIntBase(10, 10) == 1 { pass = pass + 1 }
	if math.LogIntBase(99, 10) == 1 { pass = pass + 1 }
	if math.LogIntBase(1000, 10) == 3 { pass = pass + 1 }

	// LogIntBase edge.
	if math.LogIntBase(0, 2) == -1 { pass = pass + 1 }
	if math.LogIntBase(-5, 2) == -1 { pass = pass + 1 }
	if math.LogIntBase(100, 1) == -1 { pass = pass + 1 }
	if math.LogIntBase(100, 0) == -1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 32 { ret 42 }
	ret 0
}
