// Short-circuit && / || (added while building tests-custom/apacman).
// The RHS must not evaluate when the LHS already decides the result —
// essential for the nil-guard idiom `p != nil && p.field` (which used
// to crash because both sides were always evaluated).
package main
import "log"

type Box struct {
	n int
}
fun (b *Box) Get() int { ret b.n }

fun main() int {
	var pass int = 0

	// nil-guard: p.Get() must NOT run when p is nil.
	var p *Box = nil
	if p == nil || p.Get() == 0 { pass = pass + 1 }   // no crash
	if p != nil && p.Get() == 5 { ret 1 } else { pass = pass + 1 }

	// non-nil guard: RHS runs.
	var q *Box = new Box {n: 7}
	if q != nil && q.Get() == 7 { pass = pass + 1 }

	// || short-circuits on true; && short-circuits on false.
	if true || crash() { pass = pass + 1 }
	if false && crash() { ret 2 } else { pass = pass + 1 }

	// chained
	if p == nil || q == nil || q.Get() == 99 { pass = pass + 1 }   // first true wins

	log.Println("pass=%d", pass)
	if pass == 6 { ret 42 }
	ret 0
}

// crash() would divide by zero if ever evaluated — proves non-evaluation.
fun crash() bool {
	var z int = 0
	var x int = 1 / z
	ret x == 0
}
