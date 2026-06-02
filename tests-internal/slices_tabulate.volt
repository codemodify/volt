package main
import "log"
import "slices"
import "strconv"

fun ident(i int) int { ret i }
fun square(i int) int { ret i * i }
fun fixedFive(i int) int {
	if i < 0 { ret 0 }    // dead use
	ret 5
}
fun labeled(i int) string { ret "row-" + strconv.Itoa(i) }
fun letter(i int) string { ret chr(65 + i) }   // 'A' + i

fun main() int {
	var pass int = 0

	// TabulateInt — identity.
	var a []int = slices.TabulateInt(5, ident)
	if len(a) == 5 { pass = pass + 1 }
	if a[0] == 0 { pass = pass + 1 }
	if a[4] == 4 { pass = pass + 1 }

	// TabulateInt — squares.
	var b []int = slices.TabulateInt(5, square)
	if len(b) == 5 { pass = pass + 1 }
	if b[0] == 0 { pass = pass + 1 }
	if b[3] == 9 { pass = pass + 1 }
	if b[4] == 16 { pass = pass + 1 }

	// TabulateInt — constant.
	var c []int = slices.TabulateInt(4, fixedFive)
	if len(c) == 4 { pass = pass + 1 }
	if c[0] == 5 { pass = pass + 1 }
	if c[3] == 5 { pass = pass + 1 }

	// TabulateInt — n <= 0 returns empty.
	var d []int = slices.TabulateInt(0, ident)
	if len(d) == 0 { pass = pass + 1 }
	var e []int = slices.TabulateInt(-3, ident)
	if len(e) == 0 { pass = pass + 1 }

	// TabulateInt — single element.
	var f []int = slices.TabulateInt(1, ident)
	if len(f) == 1 { pass = pass + 1 }
	if f[0] == 0 { pass = pass + 1 }

	// TabulateString — labels.
	var sa []string = slices.TabulateString(3, labeled)
	if len(sa) == 3 { pass = pass + 1 }
	if sa[0] == "row-0" { pass = pass + 1 }
	if sa[2] == "row-2" { pass = pass + 1 }

	// TabulateString — alphabet.
	var sb []string = slices.TabulateString(5, letter)
	if len(sb) == 5 { pass = pass + 1 }
	if sb[0] == "A" { pass = pass + 1 }
	if sb[4] == "E" { pass = pass + 1 }

	// TabulateString — empty.
	var sc []string = slices.TabulateString(0, labeled)
	if len(sc) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
