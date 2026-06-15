// COMPILER.multiret-recv: a MULTI-return method called on a non-ident
// receiver (`mkCalc(42).DivMod(5)`, `arr[0].DivMod(5)`) previously failed
// with "SelectorExpr multi-return needs a bare-name receiver". The receiver
// is now spilled to a local and the call recursed, mirroring the
// single-return path — no need to pre-bind the receiver.
package main

type Calc struct {
	base int
}

fun (c *Calc) DivMod(d int) (int, int) { ret c.base / d, c.base % d }
fun mkCalc(b int) *Calc { ret new Calc{base: b} }

fun main() int {
	// call-result receiver
	q, r := mkCalc(42).DivMod(5) // 42/5=8, 42%5=2
	// index-result receiver
	var cs []Calc = new(1) []Calc{}
	cs[0] = new Calc{base: 20}
	q2, r2 := cs[0].DivMod(6) // 20/6=3, 20%6=2
	if q == 8 && r == 2 && q2 == 3 && r2 == 2 {
		ret 42
	}
	ret 0
}
