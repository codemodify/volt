package main
import "log"
import "slices"

// Positive test: slices.TopNString + slices.BottomNString.

fun main() int {
	var pass int = 0

	var src []string = new(6) []string { "cherry", "apple", "banana", "date", "kiwi", "fig" }

	// TopNString — top 3 (lex desc).
	var t3 []string = slices.TopNString(src, 3)
	if len(t3) == 3 { pass = pass + 1 }
	if t3[0] == "kiwi" { pass = pass + 1 }
	if t3[1] == "fig" { pass = pass + 1 }
	if t3[2] == "date" { pass = pass + 1 }

	// TopNString — top 1.
	var t1 []string = slices.TopNString(src, 1)
	if len(t1) == 1 { pass = pass + 1 }
	if t1[0] == "kiwi" { pass = pass + 1 }

	// TopNString — n > len → full sorted.
	var tAll []string = slices.TopNString(src, 100)
	if len(tAll) == 6 { pass = pass + 1 }
	if tAll[0] == "kiwi" { pass = pass + 1 }
	if tAll[5] == "apple" { pass = pass + 1 }

	// TopNString — empty / n<=0.
	var tEmpty []string = slices.TopNString(new(0) []string {}, 3)
	if len(tEmpty) == 0 { pass = pass + 1 }
	var t0 []string = slices.TopNString(src, 0)
	if len(t0) == 0 { pass = pass + 1 }

	// BottomNString — bottom 3 (lex asc).
	var b3 []string = slices.BottomNString(src, 3)
	if len(b3) == 3 { pass = pass + 1 }
	if b3[0] == "apple" { pass = pass + 1 }
	if b3[1] == "banana" { pass = pass + 1 }
	if b3[2] == "cherry" { pass = pass + 1 }

	// BottomNString — bottom 1.
	var bb1 []string = slices.BottomNString(src, 1)
	if bb1[0] == "apple" { pass = pass + 1 }

	// BottomNString — empty.
	var bEmpty []string = slices.BottomNString(new(0) []string {}, 5)
	if len(bEmpty) == 0 { pass = pass + 1 }

	// Top[0] = max-by-lex; Bottom[0] = min-by-lex.
	if t1[0] == "kiwi" { pass = pass + 1 }
	if bb1[0] == "apple" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
