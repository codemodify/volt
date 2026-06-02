package main
import "log"
import "slices"

// Positive test: slices.UniqueByInt + UniqueByString + UniqueByStringKey.

fun abs(x int) int { if x < 0 { ret -x }; ret x }
fun parity(x int) int { if x % 2 == 0 { ret 0 }; ret 1 }
fun strLen(s string) int { ret len(s) }
fun firstByte(s string) string {
	if len(s) == 0 { ret "" }
	var out string = ""
	out = out + chr(s[0])
	ret out
}

fun main() int {
	var pass int = 0

	// UniqueByInt: dedup by absolute value — keeps first occurrence.
	var a []int = new(6) []int{3, -3, 2, -2, 1, -1}
	var ua []int = slices.UniqueByInt(a, abs)
	if len(ua) == 3 { pass = pass + 1 }
	if ua[0] == 3 { pass = pass + 1 }    // |3|=3 first
	if ua[1] == 2 { pass = pass + 1 }    // |2|=2 first
	if ua[2] == 1 { pass = pass + 1 }    // |1|=1 first

	// UniqueByInt: dedup by parity — only 2 keys exist (0 and 1).
	var b []int = new(7) []int{2, 4, 6, 1, 3, 5, 8}
	var ub []int = slices.UniqueByInt(b, parity)
	if len(ub) == 2 { pass = pass + 1 }
	if ub[0] == 2 { pass = pass + 1 }    // first even
	if ub[1] == 1 { pass = pass + 1 }    // first odd

	// Empty.
	var e []int = new(0) []int{}
	if len(slices.UniqueByInt(e, abs)) == 0 { pass = pass + 1 }

	// All same projection → keep only first.
	var c []int = new(4) []int{7, 7, 7, 7}
	var uc []int = slices.UniqueByInt(c, abs)
	if len(uc) == 1 { pass = pass + 1 }
	if uc[0] == 7 { pass = pass + 1 }

	// All distinct projections → keep all.
	var d []int = new(3) []int{1, 2, 3}
	var ud []int = slices.UniqueByInt(d, abs)
	if len(ud) == 3 { pass = pass + 1 }

	// UniqueByString: by length.
	var s []string = new(5) []string{"a", "bb", "c", "dd", "eee"}
	var us []string = slices.UniqueByString(s, strLen)
	if len(us) == 3 { pass = pass + 1 }
	if us[0] == "a" { pass = pass + 1 }     // first len=1
	if us[1] == "bb" { pass = pass + 1 }    // first len=2
	if us[2] == "eee" { pass = pass + 1 }   // first len=3

	// UniqueByStringKey: by first byte.
	var w []string = new(5) []string{"apple", "ant", "banana", "berry", "cherry"}
	var uw []string = slices.UniqueByStringKey(w, firstByte)
	if len(uw) == 3 { pass = pass + 1 }
	if uw[0] == "apple" { pass = pass + 1 }
	if uw[1] == "banana" { pass = pass + 1 }
	if uw[2] == "cherry" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
