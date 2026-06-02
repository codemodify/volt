package main
import "log"
import "slices"

// Positive test: slices.MovingAverageInt.

fun main() int {
	var pass int = 0

	// Window 3 on a constant signal.
	var c []int = new(5) []int{4, 4, 4, 4, 4}
	var mc []int = slices.MovingAverageInt(c, 3)
	if len(mc) == 3 { pass = pass + 1 }
	if mc[0] == 4 { pass = pass + 1 }
	if mc[1] == 4 { pass = pass + 1 }
	if mc[2] == 4 { pass = pass + 1 }

	// Window 3 on increasing.
	var a []int = new(5) []int{1, 2, 3, 4, 5}
	var ma []int = slices.MovingAverageInt(a, 3)
	if len(ma) == 3 { pass = pass + 1 }
	if ma[0] == 2 { pass = pass + 1 }   // (1+2+3)/3
	if ma[1] == 3 { pass = pass + 1 }   // (2+3+4)/3
	if ma[2] == 4 { pass = pass + 1 }   // (3+4+5)/3

	// Window 1 → identity.
	var b []int = new(4) []int{10, 20, 30, 40}
	var mb []int = slices.MovingAverageInt(b, 1)
	if len(mb) == 4 { pass = pass + 1 }
	if mb[0] == 10 { pass = pass + 1 }
	if mb[3] == 40 { pass = pass + 1 }

	// Window = n → single output.
	var d []int = new(4) []int{2, 4, 6, 8}
	var md []int = slices.MovingAverageInt(d, 4)
	if len(md) == 1 { pass = pass + 1 }
	if md[0] == 5 { pass = pass + 1 }   // (2+4+6+8)/4 = 5

	// Window > n → empty.
	var e []int = new(3) []int{1, 2, 3}
	var me []int = slices.MovingAverageInt(e, 5)
	if len(me) == 0 { pass = pass + 1 }

	// k = 0 → empty.
	var mz []int = slices.MovingAverageInt(a, 0)
	if len(mz) == 0 { pass = pass + 1 }

	// k < 0 → empty.
	var mn []int = slices.MovingAverageInt(a, -1)
	if len(mn) == 0 { pass = pass + 1 }

	// Empty input.
	var ee []int = new(0) []int{}
	var mee []int = slices.MovingAverageInt(ee, 3)
	if len(mee) == 0 { pass = pass + 1 }

	// Integer truncation — (1+2)/2 = 1 (not 1.5).
	var t []int = new(3) []int{1, 2, 3}
	var mt []int = slices.MovingAverageInt(t, 2)
	if mt[0] == 1 { pass = pass + 1 }   // (1+2)/2 = 1
	if mt[1] == 2 { pass = pass + 1 }   // (2+3)/2 = 2

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
