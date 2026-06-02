package main
import "log"

// Positive test: clone([]string) deep-clones each element. Previously
// cloneSlice byte-copied the backing storage only — the new slice and
// the original shared their inner string heap buffers. Now codegen
// detects non-POD element types and walks the new buffer with a
// per-element cloneValue (which heap-allocates a fresh bytes buffer
// for each string).
//
// Aliasing isn't directly observable from volt (strings are immutable)
// but the deep-clone codepath must still produce a slice whose
// elements compare equal to the originals. This test exercises the
// loop end-to-end.

fun main() int {
	var s []string = new(3) []string{"alpha", "beta", "gamma"}
	var t []string = clone(s)
	if len(t) != 3 { ret 0 }
	if t[0] != "alpha" { ret 0 }
	if t[1] != "beta" { ret 0 }
	if t[2] != "gamma" { ret 0 }
	log.Println("t[0]=%s t[1]=%s t[2]=%s", t[0], t[1], t[2])
	ret 42
}
