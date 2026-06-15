package main

// Regression for multi-file imported packages: `multifilepkg` is a
// directory of two .volt files (part_a.volt + part_b.volt). Importing it
// must surface decls from BOTH files, and a symbol defined in one file
// (Factor in part_a) must be usable from the other (Scaled in part_b).
// Returns 42 when both hold.

import (
	"fmt"
	"tests-internal/multifilepkg"
)

fun main() int {
	var (
		ok   int = 0
		want int = 2
	)
	// Sum lives in part_a.volt.
	if multifilepkg.Sum(2, 3) == 5 {
		ok = ok + 1
	}
	// Scaled lives in part_b.volt and uses Factor (=10) from part_a.volt.
	if multifilepkg.Scaled(4) == 40 {
		ok = ok + 1
	}
	fmt.Printf("import_multifile: Sum(2,3)=%d Scaled(4)=%d %d/%d\n", multifilepkg.Sum(2, 3), multifilepkg.Scaled(4), ok, want)

	if ok == want {
		ret 42
	}
	ret 1
}
