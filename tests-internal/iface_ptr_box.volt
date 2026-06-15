package main

import "fmt"

// Boxing a concrete *T into a user interface must build a {data,vtable}
// fat pointer so dispatch works and pointer-receiver mutation persists
// THROUGH the box. Before the Pass-785 codegen fix every `*T -> interface`
// boxing stored the raw *T and segfaulted on dispatch. This exercises
// every producer shape that must be recognized as a concrete *T: `new T{}`,
// a *T ident, a free-func result, a method result, and a *T struct field
// (the last two were a follow-up segfault gap, closed the same pass).
// Returns 42 on pass.
//
// NOTE: mutation persistence is asserted WITHIN one box (s1 called twice).
// One narrower limitation remains (TODO COMPILER.iface-ptr-writer): boxing
// a *T LOCAL VARIABLE auto-derefs to a value copy, so a box made from a *T
// variable doesn't share mutations with that variable. `new T{}`, call
// results, and *T fields preserve the pointer.

type Speaker interface {
	Speak() int
}

type Counter struct {
	n int
}

fun (c *Counter) Speak() int {
	c.n = c.n + 1
	ret c.n
}

fun newCounter() *Counter {
	ret new Counter {n: 0}
}

type Holder struct {
	c *Counter
}

fun (h *Holder) Get() *Counter {
	ret h.c
}

fun main() int {
	var (
		pass int = 0
		want int = 6
	)

	// 1. `new T{}` boxed; two calls prove the mutation persists in the box.
	var s1 Speaker = new Counter {n: 0}
	if s1.Speak() == 1 {
		pass = pass + 1
	}
	if s1.Speak() == 2 {
		pass = pass + 1
	}

	// 2. a *T identifier boxed and dispatched.
	var (
		cp *Counter = newCounter()
		s2 Speaker  = cp
	)
	if s2.Speak() == 1 {
		pass = pass + 1
	}

	// 3. free function returning *T boxed and dispatched.
	var s3 Speaker = newCounter()
	if s3.Speak() == 1 {
		pass = pass + 1
	}

	// 4. method returning *T boxed (was a segfault gap). The boxed *T
	//    shares the holder's counter, so the mutation persists.
	var (
		h1 *Holder = new Holder {c: newCounter()}
		s4 Speaker = h1.Get()
	)
	if s4.Speak() == 1 {
		pass = pass + 1
	}

	// 5. *T struct field boxed (was a segfault gap). Fresh holder so this
	//    counter starts at 0.
	var (
		h2 *Holder = new Holder {c: newCounter()}
		s5 Speaker = h2.c
	)
	if s5.Speak() == 1 {
		pass = pass + 1
	}

	fmt.Printf("iface_ptr_box pass=%d/%d\n", pass, want)
	if pass == want {
		ret 42
	}
	ret 1
}
