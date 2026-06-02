package main
import "log"
import "bytes"

// Positive test: bytes.Cut + bytes.SplitN. Parallel to the
// strings.Cut / strings.SplitN counterparts for []byte slices.

fun main() int {
	var pass int = 0

	// Cut: sep present (split "AB=CD" on "=").
	// 65, 66, 61, 67, 68 → ("AB", "CD", true)
	var s1 []byte = new(5) []byte{65, 66, 61, 67, 68}
	var sep1 []byte = new(1) []byte{61}
	var b1 []byte = new(0) []byte{}
	var a1 []byte = new(0) []byte{}
	var f1 bool = false
	b1, a1, f1 = bytes.Cut(s1, sep1)
	if f1 { pass = pass + 1 }
	if len(b1) == 2 { pass = pass + 1 }
	if b1[0] == 65 { pass = pass + 1 }
	if b1[1] == 66 { pass = pass + 1 }
	if len(a1) == 2 { pass = pass + 1 }
	if a1[0] == 67 { pass = pass + 1 }

	// Cut: sep absent.
	var s2 []byte = new(3) []byte{1, 2, 3}
	var sep2 []byte = new(1) []byte{99}
	var b2 []byte = new(0) []byte{}
	var a2 []byte = new(0) []byte{}
	var f2 bool = false
	b2, a2, f2 = bytes.Cut(s2, sep2)
	if !f2 { pass = pass + 1 }
	if len(b2) == 3 { pass = pass + 1 }
	if len(a2) == 0 { pass = pass + 1 }

	// Cut: empty sep → match at position 0 (before="", after=s).
	var s3 []byte = new(2) []byte{1, 2}
	var sep3 []byte = new(0) []byte{}
	var b3 []byte = new(0) []byte{}
	var a3 []byte = new(0) []byte{}
	var f3 bool = false
	b3, a3, f3 = bytes.Cut(s3, sep3)
	if f3 { pass = pass + 1 }
	if len(b3) == 0 { pass = pass + 1 }
	if len(a3) == 2 { pass = pass + 1 }

	// SplitN: n=2 on "A,B,C,D" by "," → ["A", "B,C,D"]
	var s4 []byte = new(7) []byte{65, 44, 66, 44, 67, 44, 68}
	var sep4 []byte = new(1) []byte{44}
	var p1 [][]byte = bytes.SplitN(s4, sep4, 2)
	if len(p1) == 2 { pass = pass + 1 }
	if len(p1[0]) == 1 { pass = pass + 1 }
	if p1[0][0] == 65 { pass = pass + 1 }
	if len(p1[1]) == 5 { pass = pass + 1 }
	if p1[1][0] == 66 { pass = pass + 1 }
	if p1[1][4] == 68 { pass = pass + 1 }

	// SplitN: n=1 → whole input in single element.
	var s5 []byte = new(3) []byte{1, 2, 3}
	var sep5 []byte = new(1) []byte{2}
	var p2 [][]byte = bytes.SplitN(s5, sep5, 1)
	if len(p2) == 1 { pass = pass + 1 }
	if len(p2[0]) == 3 { pass = pass + 1 }

	// SplitN: n=0 → empty.
	var s6 []byte = new(3) []byte{1, 2, 3}
	var sep6 []byte = new(1) []byte{2}
	var p3 [][]byte = bytes.SplitN(s6, sep6, 0)
	if len(p3) == 0 { pass = pass + 1 }

	// SplitN: n=-1 → unbounded (same as Split).
	var s7 []byte = new(5) []byte{1, 0, 2, 0, 3}
	var sep7 []byte = new(1) []byte{0}
	var p4 [][]byte = bytes.SplitN(s7, sep7, -1)
	if len(p4) == 3 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
