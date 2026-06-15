package main

import (
	"fmt"
	"strings"
)

// Regression for an A3 auto-free escape bug: a local slice/string/map
// stored into a composite literal that ESCAPES (returned inside a heap
// struct) must NOT be freed at the end of the constructing function.
// Before the fix, scanMovedNames didn't walk composite-literal element
// values, so `xs` below was dropped at the end of make(), and the next
// heap allocation reused its backing — turning h.Items into garbage.
// Returns 42 when the escaped data survives a subsequent allocation.

type Holder struct {
	Items []string
	Name  string
}

fun makeHolder() *Holder {
	var xs []string = new(2) []string{}
	xs[0] = "alpha"
	xs[1] = "beta"
	var nm string = "h" + "older"           // heap string, also escapes
	var h *Holder = new Holder { Items: xs, Name: nm }
	ret h
}

fun main() int {
	var pass int = 0
	var want int = 4

	var h *Holder = makeHolder()
	// Force heap churn: if make() freed xs/nm, this reuses the memory.
	var junk string = strings.Repeat("z", 4096)
	var junk2 []string = new(64) []string{}
	junk2[0] = strings.Repeat("q", 100)

	if len(h.Items) == 2 { pass = pass + 1 }
	if h.Items[0] == "alpha" { pass = pass + 1 }
	if h.Items[1] == "beta" { pass = pass + 1 }
	if h.Name == "holder" { pass = pass + 1 }

	fmt.Printf("a3-escape items=[%s,%s] name=[%s] junk=%d j2=%d pass=%d/%d\n",
		h.Items[0], h.Items[1], h.Name, len(junk), len(junk2), pass, want)
	if pass == want { ret 42 }
	ret 1
}
