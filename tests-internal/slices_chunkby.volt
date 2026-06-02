package main
import "log"
import "slices"

fun parity(x int) int { ret x % 2 }
fun sign(x int) int {
	if x > 0 { ret 1 }
	if x < 0 { ret -1 }
	ret 0
}
fun lenKey(s string) int { ret len(s) }
fun firstChar(s string) int {
	if len(s) == 0 { ret 0 }
	ret s[0] & 255
}

fun main() int {
	var pass int = 0

	// ChunkByInt — group by parity.
	// [1, 3, 2, 4, 5] → [[1,3], [2,4], [5]]
	var a []int = new(5) []int { 1, 3, 2, 4, 5 }
	var ca [][]int = slices.ChunkByInt(a, parity)
	if len(ca) == 3 { pass = pass + 1 }
	if len(ca[0]) == 2 { pass = pass + 1 }
	if ca[0][0] == 1 { pass = pass + 1 }
	if ca[0][1] == 3 { pass = pass + 1 }
	if len(ca[1]) == 2 { pass = pass + 1 }
	if ca[1][0] == 2 { pass = pass + 1 }
	if len(ca[2]) == 1 { pass = pass + 1 }
	if ca[2][0] == 5 { pass = pass + 1 }

	// ChunkByInt — group by sign.
	// [-2, -1, 0, 1, 2] → [[-2,-1], [0], [1,2]]
	var b []int = new(5) []int { -2, -1, 0, 1, 2 }
	var cb [][]int = slices.ChunkByInt(b, sign)
	if len(cb) == 3 { pass = pass + 1 }
	if len(cb[0]) == 2 { pass = pass + 1 }
	if len(cb[1]) == 1 { pass = pass + 1 }
	if cb[1][0] == 0 { pass = pass + 1 }
	if len(cb[2]) == 2 { pass = pass + 1 }

	// ChunkByInt — all same key → single chunk.
	var c []int = new(4) []int { 2, 4, 6, 8 }
	var cc [][]int = slices.ChunkByInt(c, parity)
	if len(cc) == 1 { pass = pass + 1 }
	if len(cc[0]) == 4 { pass = pass + 1 }

	// ChunkByInt — empty → empty.
	var d []int = new(0) []int {}
	var cd [][]int = slices.ChunkByInt(d, parity)
	if len(cd) == 0 { pass = pass + 1 }

	// ChunkByInt — single element → one chunk of 1.
	var e []int = new(1) []int { 42 }
	var ce [][]int = slices.ChunkByInt(e, parity)
	if len(ce) == 1 { pass = pass + 1 }
	if ce[0][0] == 42 { pass = pass + 1 }

	// ChunkByString — group by length.
	// ["a", "b", "cc", "dd", "eee"] → [["a","b"], ["cc","dd"], ["eee"]]
	var sa []string = new(5) []string { "a", "b", "cc", "dd", "eee" }
	var csa [][]string = slices.ChunkByString(sa, lenKey)
	if len(csa) == 3 { pass = pass + 1 }
	if len(csa[0]) == 2 { pass = pass + 1 }
	if csa[0][0] == "a" { pass = pass + 1 }
	if len(csa[1]) == 2 { pass = pass + 1 }
	if csa[1][0] == "cc" { pass = pass + 1 }
	if len(csa[2]) == 1 { pass = pass + 1 }

	// ChunkByString — group by first char.
	// ["apple", "apricot", "banana", "blueberry", "cherry"] grouped by first char.
	var sb []string = new(5) []string { "apple", "apricot", "banana", "blueberry", "cherry" }
	var csb [][]string = slices.ChunkByString(sb, firstChar)
	if len(csb) == 3 { pass = pass + 1 }
	if len(csb[0]) == 2 { pass = pass + 1 }
	if csb[0][0] == "apple" { pass = pass + 1 }
	if len(csb[2]) == 1 { pass = pass + 1 }
	if csb[2][0] == "cherry" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 29 { ret 42 }
	ret 0
}
