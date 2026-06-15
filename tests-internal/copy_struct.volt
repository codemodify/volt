// Copy structs: a struct whose fields are ALL Copy (recursively —
// primitives or other all-Copy structs) is itself Copy. It can be passed
// BY VALUE to a function that forwards it onward (which moves a movable
// type) and still be REUSED afterward. Structs with a string/slice/
// pointer field stay movable (covered by use_after_move & friends).
package main

import "log"

type Pt struct {
	x int
	y int
}

// Box's fields are themselves all-Copy structs -> Box is Copy (recursive).
type Box struct {
	tl Pt
	br Pt
}

type Sink struct {
	acc int
}

// Add takes Pt by value; forward hands its Pt param on to Add (a method),
// which is exactly the shape that MOVES a movable value.
fun (s *Sink) Add(p Pt) {
	s.acc = s.acc + p.x + p.y
}

fun forward(s *Sink, p Pt) {
	s.Add(p)
}

fun area(b Box) int {
	ret (b.br.x - b.tl.x) * (b.br.y - b.tl.y)
}

fun main() int {
	var s *Sink = new Sink {acc: 0}
	var p Pt = new Pt {x: 3, y: 4}
	forward(s, p) // would MOVE p under the old "every struct moves" model
	forward(s, p) // reuse-after-pass — only legal because Pt is Copy

	var b Box = new Box {tl: new Pt {x: 0, y: 0}, br: new Pt {x: 5, y: 2}}
	var a1 int = area(b)
	var a2 int = area(b) // reuse a nested all-Copy struct

	log.Println("acc=%d a1=%d a2=%d", s.acc, a1, a2)
	if s.acc == 14 && a1 == 10 && a2 == 10 {
		ret 42
	}
	ret 1
}
