package main
import "log"
import "slices"

// Positive test: slices.ChunkInt / ChunkString. Splits into
// consecutive chunks; last chunk may be shorter.

fun main() int {
	var pass int = 0

	// Evenly divisible: 6 elements, chunk size 2 → 3 chunks of 2.
	var s1 []int = new(6) []int{1, 2, 3, 4, 5, 6}
	var c1 [][]int = slices.ChunkInt(s1, 2)
	if len(c1) == 3 { pass = pass + 1 }
	if len(c1[0]) == 2 { pass = pass + 1 }
	if c1[0][0] == 1 { pass = pass + 1 }
	if c1[0][1] == 2 { pass = pass + 1 }
	if c1[1][0] == 3 { pass = pass + 1 }
	if c1[2][1] == 6 { pass = pass + 1 }

	// Uneven: 7 elements, chunk size 3 → 3 chunks (3, 3, 1).
	var s2 []int = new(7) []int{10, 20, 30, 40, 50, 60, 70}
	var c2 [][]int = slices.ChunkInt(s2, 3)
	if len(c2) == 3 { pass = pass + 1 }
	if len(c2[0]) == 3 { pass = pass + 1 }
	if len(c2[1]) == 3 { pass = pass + 1 }
	if len(c2[2]) == 1 { pass = pass + 1 }
	if c2[2][0] == 70 { pass = pass + 1 }

	// Chunk size larger than slice: single chunk = s.
	var s3 []int = new(3) []int{1, 2, 3}
	var c3 [][]int = slices.ChunkInt(s3, 10)
	if len(c3) == 1 { pass = pass + 1 }
	if len(c3[0]) == 3 { pass = pass + 1 }

	// Empty slice → empty result.
	var s4 []int = new(0) []int{}
	var c4 [][]int = slices.ChunkInt(s4, 3)
	if len(c4) == 0 { pass = pass + 1 }

	// size <= 0 → empty.
	var s5 []int = new(3) []int{1, 2, 3}
	var c5 [][]int = slices.ChunkInt(s5, 0)
	if len(c5) == 0 { pass = pass + 1 }
	var c6 [][]int = slices.ChunkInt(s5, -1)
	if len(c6) == 0 { pass = pass + 1 }

	// ChunkString variant.
	var s6 []string = new(5) []string{"a", "b", "c", "d", "e"}
	var c7 [][]string = slices.ChunkString(s6, 2)
	if len(c7) == 3 { pass = pass + 1 }
	if c7[0][0] == "a" { pass = pass + 1 }
	if c7[2][0] == "e" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
