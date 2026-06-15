// Regression (codegen): assigning a pointer VARIABLE into a `[]*T` element
// must store the raw pointer. emitSliceIndexAssign used to auto-deref the
// RHS pointer ident into a struct value (`load %T`), then `store ptr <value>`
// → clang "expected 'ptr'". Exercised by an insertion sort that swaps
// elements (`xs[j] = tmp`).

package main

import "log"

type item struct {
	name  string
	score int
}

fun sortItems(xs []*item) []*item {
	for i := 1; i < len(xs); i = i + 1 {
		var j int = i
		for j > 0 && xs[j - 1].score > xs[j].score {
			var tmp *item = xs[j - 1]
			xs[j - 1] = xs[j]
			xs[j] = tmp
			j = j - 1
		}
	}
	ret xs
}

fun main() int {
	var xs []*item = new(0) []*item {}
	var a *item = new item {name: "c", score: 3}
	xs = append(xs, a)
	var b *item = new item {name: "a", score: 1}
	xs = append(xs, b)
	var c *item = new item {name: "b", score: 2}
	xs = append(xs, c)

	xs = sortItems(xs)

	// After the sort the scores ascend 1,2,3.
	var ok int = 0
	if xs[0].score == 1 { ok = ok + 1 }
	if xs[1].score == 2 { ok = ok + 1 }
	if xs[2].score == 3 { ok = ok + 1 }
	log.Println("ok=%d/3", ok)
	if ok == 3 { ret 42 }
	ret 0
}
