// group_decls.volt — grouped `const ( ... )` and `var ( ... )` blocks
// (Go-style). Exercises: mixed typed/untyped consts in a group, a group
// member with no initializer (`c int`), and a single `var` after a group.
// Also serves as a `volt fmt` round-trip case (fmt_smoke must re-emit the
// groups and still build + run to 42).

package main

import "log"

const (
	Base   int = 40 // trailing comment on a grouped member
	Bonus      = 2
	// an own-line comment inside the group must keep the block together
	Zero int = 0
)

const Solo = 1

fun main() int {
	var (
		a int = Base // trailing comment in a var group
		b int = Bonus
		c int
	)
	c = a + b
	var d int = c - Zero + Solo - Solo
	log.Println("c=%d d=%d", c, d)
	if Base == 40 && Bonus == 2 && Zero == 0 && Solo == 1 && d == 42 {
		ret 42
	}
	ret 0
}
