// Method-argument borrow checks (item 4): a method's own `&mut`/`&`
// parameters get the same call-site borrow tracking as free-function
// args. Positive cases — no conflicting borrow held.
package main
import "log"

type Box struct {
	v int
}

fun (b &Box) addInto(dst &mut int) { *dst = *dst + b.v }
fun (b &Box) readInto(dst &mut int) { *dst = b.v }

fun main() int {
	var bx Box = new Box {v: 5}
	var t int = 10

	// Sequential &mut-arg method calls: each borrow ends on return.
	bx.addInto(&mut t)
	if t != 15 { ret 1 }
	bx.addInto(&mut t)
	if t != 20 { ret 2 }

	bx.readInto(&mut t)
	if t != 5 { ret 3 }

	log.Println("method arg borrow ok: t=%d", t)
	ret 42
}
