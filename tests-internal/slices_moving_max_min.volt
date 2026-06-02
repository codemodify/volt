package main
import "log"
import "slices"

// Positive test: slices.MovingMaxInt + slices.MovingMinInt.

fun main() int {
	var pass int = 0

	// MovingMaxInt — basic ascending.
	var a []int = new(5) []int{1, 2, 3, 4, 5}
	var ma []int = slices.MovingMaxInt(a, 3)
	if len(ma) == 3 { pass = pass + 1 }
	if ma[0] == 3 { pass = pass + 1 }
	if ma[1] == 4 { pass = pass + 1 }
	if ma[2] == 5 { pass = pass + 1 }

	// MovingMaxInt — peak in middle.
	var b []int = new(6) []int{1, 5, 2, 8, 3, 1}
	var mb []int = slices.MovingMaxInt(b, 3)
	if len(mb) == 4 { pass = pass + 1 }
	if mb[0] == 5 { pass = pass + 1 }    // max(1,5,2)
	if mb[1] == 8 { pass = pass + 1 }    // max(5,2,8)
	if mb[2] == 8 { pass = pass + 1 }    // max(2,8,3)
	if mb[3] == 8 { pass = pass + 1 }    // max(8,3,1)

	// k=1 → identity.
	var mc []int = slices.MovingMaxInt(a, 1)
	if len(mc) == 5 { pass = pass + 1 }
	if mc[2] == 3 { pass = pass + 1 }

	// k=n → single max.
	var md []int = slices.MovingMaxInt(a, 5)
	if len(md) == 1 { pass = pass + 1 }
	if md[0] == 5 { pass = pass + 1 }

	// k>n → empty.
	var me []int = slices.MovingMaxInt(a, 10)
	if len(me) == 0 { pass = pass + 1 }

	// k=0 → empty.
	var mz []int = slices.MovingMaxInt(a, 0)
	if len(mz) == 0 { pass = pass + 1 }

	// MovingMinInt — basic.
	var mn []int = slices.MovingMinInt(b, 3)
	if len(mn) == 4 { pass = pass + 1 }
	if mn[0] == 1 { pass = pass + 1 }    // min(1,5,2)
	if mn[1] == 2 { pass = pass + 1 }    // min(5,2,8)
	if mn[2] == 2 { pass = pass + 1 }    // min(2,8,3)
	if mn[3] == 1 { pass = pass + 1 }    // min(8,3,1)

	// MovingMinInt — k=1 identity.
	var mn1 []int = slices.MovingMinInt(a, 1)
	if mn1[0] == 1 { pass = pass + 1 }
	if mn1[4] == 5 { pass = pass + 1 }

	// MovingMinInt — k=n single min.
	var mn_n []int = slices.MovingMinInt(a, 5)
	if len(mn_n) == 1 { pass = pass + 1 }
	if mn_n[0] == 1 { pass = pass + 1 }

	// Negatives.
	var neg []int = new(4) []int{-5, -2, -8, -3}
	var mneg []int = slices.MovingMaxInt(neg, 2)
	if mneg[0] == -2 { pass = pass + 1 }
	if mneg[1] == -2 { pass = pass + 1 }
	if mneg[2] == -3 { pass = pass + 1 }

	// Empty input.
	var ee []int = new(0) []int{}
	var mee []int = slices.MovingMaxInt(ee, 3)
	if len(mee) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 28 { ret 42 }
	ret 0
}
