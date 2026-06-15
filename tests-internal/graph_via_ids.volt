// graph_via_ids — POSITIVE.
//
// The model's sanctioned "graph" workaround: nodes in a slice, edges as int
// ids (no pointers, no cycles). Exercises nested field-assignment on a
// value-element slice (`nodes[i].next = id`) and reading a Copy field of a
// slice element without consuming the slice (`cur = nodes[cur].next`).

package main

import "log"

type Node struct {
    val  int
    next int
}

fun main() int {
    var nodes []Node = new(0) []Node{}
    nodes = append(nodes, new Node{val: 1, next: -1})
    nodes = append(nodes, new Node{val: 2, next: -1})
    nodes = append(nodes, new Node{val: 3, next: -1})

    nodes[0].next = 1            // nested field-assign on a value element
    nodes[1].next = 2

    var cur int = 0
    var sum int = 0
    for cur != -1 {
        sum = sum + nodes[cur].val      // read Copy field — no move
        cur = nodes[cur].next
    }
    log.Println("walk sum=%d", sum)
    if sum != 6 { ret 1 }
    if nodes[0].next != 1 { ret 2 }
    ret 42
}
