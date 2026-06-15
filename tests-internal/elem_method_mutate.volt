// elem_method_mutate — POSITIVE.
//
// A pointer-receiver method called on a slice ELEMENT (`s[i].Mutate()`)
// changes the element IN PLACE — not a throwaway copy. Covers value-element
// slices ([]T, the fix), pointer-element slices ([]*T), and a value receiver.

package main

import "log"

type Counter struct {
    n int
}
fun (c *Counter) Bump() { c.n = c.n + 1 }

type Box struct {
    v int
}
fun (b Box) Get() int { ret b.v }

fun main() int {
    var cs []Counter = new(0) []Counter{}
    cs = append(cs, new Counter{n: 10})
    cs[0].Bump()
    cs[0].Bump()
    if cs[0].n != 12 { ret 1 }        // value element: mutated in place

    var ps []*Counter = new(0) []*Counter{}
    ps = append(ps, new Counter{n: 5})
    ps[0].Bump()
    if ps[0].n != 6 { ret 2 }         // pointer element: still works

    var bs []Box = new(0) []Box{}
    bs = append(bs, new Box{v: 99})
    if bs[0].Get() != 99 { ret 3 }    // value receiver: reads correctly

    log.Println("element method mutate: in-place OK")
    ret 42
}
