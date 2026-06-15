// []*T method calls and field reads on slice ELEMENTS, including a slice
// reached through a struct FIELD (g.cells[i].M()), plus append(slice,
// new T{...}) heap-boxing the struct literal into the slice's pointer
// element. Exercises the codegen paths fixed alongside the Copy-struct
// work: spillIndexResultAsLocal / pointeeStructName element-type
// recovery for field slices, and emitBuiltinAppend pointer boxing.
package main

import "log"

type Cell struct {
	v int
}

fun (c *Cell) Bump(d int) {
	c.v = c.v + d
}

type Grid struct {
	cells []*Cell
}

// append(g.cells, new Cell{...}) — the literal is boxed onto the heap and
// its pointer stored into the []*Cell element slot.
fun (g *Grid) Add(v int) {
	g.cells = append(g.cells, new Cell {v: v})
}

fun main() int {
	var g *Grid = new Grid {cells: new(0) []*Cell {}}
	g.Add(10)
	g.Add(20)

	g.cells[0].Bump(5) // method call on a field-slice-of-pointers element
	g.cells[1].Bump(2)

	// Field reads on field-slice-of-pointers elements (auto-deref).
	var sum int = g.cells[0].v + g.cells[1].v

	log.Println("v0=%d v1=%d sum=%d", g.cells[0].v, g.cells[1].v, sum)
	if g.cells[0].v == 15 && g.cells[1].v == 22 && sum == 37 {
		ret 42
	}
	ret 1
}
