package main
import "log"
import "bytes"

// Positive test: bytes.ToLower / ToUpper / Repeat. Parallel to the
// strings.* equivalents but for []byte slices. ASCII-only case fold
// (non-letter bytes pass through).

fun main() int {
	var pass int = 0

	// ToLower: 'H' (72), 'I' (73) → 'h' (104), 'i' (105).
	var src []byte = new(2) []byte{72, 73}
	var lo []byte = bytes.ToLower(src)
	if lo[0] == 104 { pass = pass + 1 }
	if lo[1] == 105 { pass = pass + 1 }

	// ToLower: non-letter bytes pass through (0x00, 'a', '5', '!').
	var src2 []byte = new(4) []byte{0, 97, 53, 33}
	var lo2 []byte = bytes.ToLower(src2)
	if lo2[0] == 0 { pass = pass + 1 }
	if lo2[1] == 97 { pass = pass + 1 }
	if lo2[2] == 53 { pass = pass + 1 }
	if lo2[3] == 33 { pass = pass + 1 }

	// ToUpper: 'h' (104), 'i' (105) → 'H' (72), 'I' (73).
	var src3 []byte = new(2) []byte{104, 105}
	var up []byte = bytes.ToUpper(src3)
	if up[0] == 72 { pass = pass + 1 }
	if up[1] == 73 { pass = pass + 1 }

	// ToUpper: already-upper passes through.
	var src4 []byte = new(2) []byte{72, 73}
	var up2 []byte = bytes.ToUpper(src4)
	if up2[0] == 72 { pass = pass + 1 }
	if up2[1] == 73 { pass = pass + 1 }

	// Repeat: 'AB' x 3 → 'ABABAB' (6 bytes).
	var src5 []byte = new(2) []byte{65, 66}
	var rep []byte = bytes.Repeat(src5, 3)
	if len(rep) == 6 { pass = pass + 1 }
	if rep[0] == 65 { pass = pass + 1 }
	if rep[1] == 66 { pass = pass + 1 }
	if rep[5] == 66 { pass = pass + 1 }

	// Repeat: count == 0 → empty.
	var src6 []byte = new(2) []byte{1, 2}
	var rep2 []byte = bytes.Repeat(src6, 0)
	if len(rep2) == 0 { pass = pass + 1 }

	// Repeat: negative count → empty.
	var src7 []byte = new(2) []byte{1, 2}
	var rep3 []byte = bytes.Repeat(src7, -1)
	if len(rep3) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
