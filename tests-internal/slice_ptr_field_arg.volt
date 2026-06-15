// Regression (borrow checker): reading a movable field THROUGH a pointer
// element (`sliceOfPtrs[i].field`) and passing it as a function argument
// must NOT mark the whole slice as moved. The slice owns pointers, not the
// pointed-to values, so the read only borrows the field. Before the fix,
// the first such read flagged every later use of the slice as "use of moved".

package main

import "fmt"
import "log"

type rec struct {
	name string
	n    int
}

fun shout(s string) string { ret s + "!" }

fun main() int {
	var xs []*rec = new(0) []*rec {}
	var a *rec = new rec {name: "x", n: 7}
	xs = append(xs, a)

	var hits int = 0
	for k := 0; k < len(xs); k = k + 1 {
		fmt.Println(shout(xs[k].name)) // field read thru ptr, as a call arg
		fmt.Println(xs[k].name)        // read the same field again
		hits = hits + xs[k].n          // and keep using the slice afterwards
	}
	log.Println("hits=%d", hits)
	if len(xs) == 1 && hits == 7 { ret 42 }
	ret 0
}
