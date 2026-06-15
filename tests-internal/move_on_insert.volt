// move_on_insert — POSITIVE.
//
// Appending consumes a MOVABLE element (don't reuse it), but a COPY element
// (int / all-Copy struct) duplicates and stays usable, and append in a loop
// is fine.

package main

import "log"

type Note struct {
    text string
}

fun main() int {
    var notes []Note = new(0) []Note{}
    var n Note = new Note{text: "hi"}
    notes = append(notes, n)         // movable: moved in, not reused

    var nums []int = new(0) []int{}
    var k int = 7
    nums = append(nums, k)
    nums = append(nums, k)            // copy: k reusable

    var i int = 0
    for i = 0; i < 3; i++ {
        nums = append(nums, i)
    }

    log.Println("notes=%d nums=%d k=%d", len(notes), len(nums), k)
    if len(notes) != 1 { ret 1 }
    if len(nums) != 5 { ret 2 }
    ret 42
}
