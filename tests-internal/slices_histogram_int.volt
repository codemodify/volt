package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty slice → empty map.
	var empty []int = new(0) []int {}
	var h0 map[string]int = slices.HistogramInt(empty)
	if len(h0) == 0 { pass = pass + 1 }

	// All-unique values.
	var u []int = new(3) []int { 1, 2, 3 }
	var h1 map[string]int = slices.HistogramInt(u)
	if len(h1) == 3 { pass = pass + 1 }
	if h1["1"] == 1 { pass = pass + 1 }
	if h1["2"] == 1 { pass = pass + 1 }
	if h1["3"] == 1 { pass = pass + 1 }

	// All-same → single key with full count.
	var same []int = new(5) []int { 7, 7, 7, 7, 7 }
	var h2 map[string]int = slices.HistogramInt(same)
	if len(h2) == 1 { pass = pass + 1 }
	if h2["7"] == 5 { pass = pass + 1 }

	// Mixed frequencies — typical vote tally.
	var votes []int = new(10) []int { 1, 2, 1, 3, 2, 1, 4, 2, 1, 3 }
	var h3 map[string]int = slices.HistogramInt(votes)
	if len(h3) == 4 { pass = pass + 1 }
	if h3["1"] == 4 { pass = pass + 1 }
	if h3["2"] == 3 { pass = pass + 1 }
	if h3["3"] == 2 { pass = pass + 1 }
	if h3["4"] == 1 { pass = pass + 1 }

	// Negative values keyed by signed-decimal string.
	var neg []int = new(4) []int { -1, -2, -1, 0 }
	var h4 map[string]int = slices.HistogramInt(neg)
	if len(h4) == 3 { pass = pass + 1 }
	if h4["-1"] == 2 { pass = pass + 1 }
	if h4["-2"] == 1 { pass = pass + 1 }
	if h4["0"] == 1 { pass = pass + 1 }

	// Single-element slice.
	var solo []int = new(1) []int { 42 }
	var h5 map[string]int = slices.HistogramInt(solo)
	if len(h5) == 1 { pass = pass + 1 }
	if h5["42"] == 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
