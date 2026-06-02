package main
import "log"
import "slices"
import "time"

// Positive test: slices.MoveInt + slices.MoveString + (t Time).HMS.

fun main() int {
	var pass int = 0

	// MoveInt — forward (later index).
	var a []int = new(5) []int{10, 20, 30, 40, 50}
	a = slices.MoveInt(a, 0, 3)
	// Expected: 20, 30, 40, 10, 50.
	if a[0] == 20 { pass = pass + 1 }
	if a[1] == 30 { pass = pass + 1 }
	if a[2] == 40 { pass = pass + 1 }
	if a[3] == 10 { pass = pass + 1 }
	if a[4] == 50 { pass = pass + 1 }

	// MoveInt — backward (earlier index).
	var b []int = new(5) []int{10, 20, 30, 40, 50}
	b = slices.MoveInt(b, 3, 1)
	// Expected: 10, 40, 20, 30, 50.
	if b[0] == 10 { pass = pass + 1 }
	if b[1] == 40 { pass = pass + 1 }
	if b[2] == 20 { pass = pass + 1 }
	if b[3] == 30 { pass = pass + 1 }
	if b[4] == 50 { pass = pass + 1 }

	// MoveInt — same index is no-op.
	var c []int = new(3) []int{1, 2, 3}
	c = slices.MoveInt(c, 1, 1)
	if c[1] == 2 { pass = pass + 1 }

	// Out of bounds.
	var d []int = new(3) []int{1, 2, 3}
	d = slices.MoveInt(d, 10, 1)
	if d[1] == 2 { pass = pass + 1 }
	d = slices.MoveInt(d, 1, -1)
	if d[1] == 2 { pass = pass + 1 }

	// MoveString.
	var s []string = new(4) []string{"a", "b", "c", "d"}
	s = slices.MoveString(s, 0, 2)
	if s[0] == "b" { pass = pass + 1 }
	if s[1] == "c" { pass = pass + 1 }
	if s[2] == "a" { pass = pass + 1 }
	if s[3] == "d" { pass = pass + 1 }

	// HMS.
	var t time.Time = time.Date(2024, 3, 15, 14, 30, 45, 0)
	var h int = 0
	var m int = 0
	var sec int = 0
	h, m, sec = t.HMS()
	if h == 14 { pass = pass + 1 }
	if m == 30 { pass = pass + 1 }
	if sec == 45 { pass = pass + 1 }

	// HMS midnight.
	var t2 time.Time = time.Date(2024, 3, 15, 0, 0, 0, 0)
	h, m, sec = t2.HMS()
	if h == 0 { pass = pass + 1 }
	if m == 0 { pass = pass + 1 }
	if sec == 0 { pass = pass + 1 }

	// HMS last second.
	var t3 time.Time = time.Date(2024, 3, 15, 23, 59, 59, 0)
	h, m, sec = t3.HMS()
	if h == 23 { pass = pass + 1 }
	if m == 59 { pass = pass + 1 }
	if sec == 59 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
