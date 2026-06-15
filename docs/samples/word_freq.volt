// word_freq — count word frequencies in a body of text and report the
// busiest word. A deliberately realistic data-processing shape, annotated to
// show how the memory model plays out — and where it does NOT yet reclaim.
//
// THE THREE BUCKETS in one function (see docs/design/2-ownership.md):
//   - Copy:   int counters (total, best, i) — bit-copied, nothing to free.
//   - Owned:  the []string of words and the map[string]int — one owner each,
//             freed when `analyze` returns. No GC, no manual free.
//   - (no Shared-handle here; see worker_pool.volt for channels.)
//
// MEASURED (1,000,000 calls to analyze): time ~6.8 s, VmHWM ~2.6 GB.
// That memory is NOT flat — and the reason is the most important thing this
// sample teaches: **owned data that arrives from a function RETURN is not yet
// reclaimed.** `strings.Fields(text)` and `maps.KeysStringInt(counts)` each
// hand back an owned []string the caller should free at scope end, but the
// compiler can't yet tell an owned return from a borrowed/aliased one, so it
// conservatively leaks them. Locally-`new`'d owned containers ARE reclaimed
// (their backing + element payloads); function-return owned containers are
// the open gap — tracked as the "ownership signatures" / return-ownership
// work (S3). For real programs this return-ownership gap dominates the memory
// profile, far more than element-payload reclamation of local containers.

package main

import "strings"
import "maps"
import "log"

fun analyze(text string) int {
	// words: OWNED []string — BUT it comes from a function return, so today it
	// LEAKS at scope end (return-ownership gap). A locally-built
	// `new(n) []string{...}` would instead be freed here.
	var words []string = strings.Fields(text)

	// counts: OWNED map, built locally with `new` → fully reclaimed at scope
	// end (its key copies are freed; the int values are Copy, nothing to free).
	var counts map[string]int = new map[string]int
	for i := 0; i < len(words); i++ {
		var w string = words[i] // index-binding read → an INDEPENDENT copy
		counts[w] = counts[w] + 1 // w is copied into the map as a key
	}

	// keys: OWNED []string from a function return → also LEAKS today (S3).
	var keys []string = maps.KeysStringInt(counts)
	var best int = 0
	for i := 0; i < len(keys); i++ {
		var k string = keys[i]
		if counts[k] > best {
			best = counts[k]
		}
	}
	ret best
}

fun main() int {
	var text string = "the quick brown fox the lazy dog the fox the"
	var acc int = 0
	for n := 0; n < 1000; n++ {
		acc = acc + analyze(text) // "the" wins with 4
	}
	log.Println("busiest-word count summed over %d runs = %d", 1000, acc)
	if acc == 4000 {
		ret 42
	}
	ret 0
}
