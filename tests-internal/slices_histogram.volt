package main
import "log"
import "slices"

// Positive test: slices.HistogramString.

fun main() int {
	var pass int = 0

	// Basic counts.
	var a []string = new(6) []string{"a", "b", "a", "c", "b", "a"}
	var h map[string]int = slices.HistogramString(a)
	if h["a"] == 3 { pass = pass + 1 }
	if h["b"] == 2 { pass = pass + 1 }
	if h["c"] == 1 { pass = pass + 1 }
	if len(h) == 3 { pass = pass + 1 }

	// Missing key returns 0 (Go map zero-value semantics).
	if h["zzz"] == 0 { pass = pass + 1 }

	// All distinct — every count is 1.
	var b []string = new(4) []string{"w", "x", "y", "z"}
	var hb map[string]int = slices.HistogramString(b)
	if len(hb) == 4 { pass = pass + 1 }
	if hb["w"] == 1 { pass = pass + 1 }
	if hb["z"] == 1 { pass = pass + 1 }

	// All same.
	var c []string = new(5) []string{"hi", "hi", "hi", "hi", "hi"}
	var hc map[string]int = slices.HistogramString(c)
	if len(hc) == 1 { pass = pass + 1 }
	if hc["hi"] == 5 { pass = pass + 1 }

	// Empty.
	var d []string = new(0) []string{}
	var hd map[string]int = slices.HistogramString(d)
	if len(hd) == 0 { pass = pass + 1 }

	// Empty strings count as a key.
	var e []string = new(3) []string{"", "", "x"}
	var he map[string]int = slices.HistogramString(e)
	if he[""] == 2 { pass = pass + 1 }
	if he["x"] == 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
