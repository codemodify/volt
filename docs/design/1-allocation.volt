// =====================================================================
// 1-allocation.volt — the `new` keyword
// =====================================================================
// `new` is the one heap-allocation primitive. There is no `make`.
//
// FULL GRAMMAR — size always comes immediately after `new`, before the type:
//
//   new T              — bare (legal only for struct default-construct)
//   new(s) T           — sized:   chan cap | slice len | map cap hint
//   new T{i}           — init:    struct fields | map entries | slice elems
//   new(s) T{i}        — sized + init  (slice with length=s, map with cap=s)
//
// SHORT FORM — the type is omitted when the LHS of the same `=` supplies
// it via an explicit type annotation:
//
//   var c Counter         = new {value: 10}
//   var ch chan int       = new(4)
//   var m map[string]int  = new {}
//   var s []int           = new(8) {1, 2, 3}
//
// Short form is allowed ONLY on a `var x T = new...` declaration. For
// `x = new...`, `x := new...`, return, function args, or slice/map
// elements, the type must be written.
//
// BRACE CONTENT differs by target type:
//   - struct: named-field syntax     `{value: 10}`
//   - map:    expression keys         `{"a": 1}`
//   - slice:  positional elements    `{1, 2, 3}`
// The compiler picks based on the LHS type; mismatches are errors.
//
// In every case, `new` returns OWNED `T`.
//
//   volt run docs/design/1-allocation.volt

package main

import "log"

type Counter struct {
    value int
}

fun main() {
    // ---- Structs ----------------------------------------------------------
    var a Counter = new Counter{value: 1}      // long, fields
    var b Counter = new Counter{}              // long, default
    var c Counter = new {value: 7}             // short, fields
    var d Counter = new {}                     // short, default

    // ---- Channels ---------------------------------------------------------
    var ch chan int = new(4) chan int          // long, cap=4
    var u  chan int = new(1)                   // short, cap=1

    // ---- Maps -------------------------------------------------------------
    var m1 map[string]int = new(3) map[string]int{"x": 1, "y": 2, "z": 3}  // long, initial-capacity, entries    (capacity-explicit, type-explicit, entries-explicit)
    var m2 map[string]int = new(3) map[string]int{}                        // long, initial-capacity             (capacity-explicit, type-explicit, entries-inferred)
    var m3 map[string]int = new map[string]int{"x": 1, "y": 2, "z": 3}     // long, entries                     (capacity-inferred, type-explicit, entries-explicit)
    var m4 map[string]int = new map[string]int{}                           // long, empty                        (capacity-inferred, type-explicit, entries-inferred)

    var m5 map[string]int = new(3) {"x": 1, "y": 2, "z": 3}                // short, initial-capacity + entries  (capacity-explicit, type-inferred, entries-explicit)
    var m6 map[string]int = new(3) {}                                      // short, initial-capacity            (capacity-explicit, type-inferred, entries-inferred)
    var m7 map[string]int = new {"x": 1, "y": 2, "z": 3}                   // short, entries                    (capacity-inferred, type-inferred, entries-explicit)
    var m8 map[string]int = new {}                                         // short, empty                       (capacity-inferred, type-inferred, entries-inferred)

    // ---- Slices -----------------------------------------------------------
    var s1 []int = new(3) []int{1, 2, 3}                                   // long, initial-length, entries    (length-explicit, type-explicit, entries-explicit)
    var s2 []int = new(3) []int{}                                          // long, initial-length             (length-explicit, type-explicit, entries-inferred)
    var s3 []int = new []int{1, 2, 3}                                      // long, entries                    (length-inferred, type-explicit, entries-explicit)
    var s4 []int = new []int{}                                             // long, empty                      (length-inferred, type-explicit, entries-inferred)

    var s5 []int = new(3) {1, 2, 3}                                        // short, initial-length, entries   (length-explicit, type-inferred, entries-explicit)
    var s6 []int = new(3) {}                                               // short, initial-length            (length-explicit, type-inferred, entries-inferred)
    var s7 []int = new {1, 2, 3}                                           // short, entries                   (length-inferred, type-inferred, entries-explicit)
    var s8 []int = new {}                                                  // short, empty                     (length-inferred, type-inferred, entries-inferred)

    // Exercise everything so codegen retains it.
    write(ch, a.value)
    write(ch, b.value)
    write(ch, c.value)
    write(ch, d.value)
    write(u, 99)
    m2["z"] = 3
    m3["q"] = 4

    var sum int = read(ch) + read(ch) + read(ch) + read(ch) + read(u)

    // Touch every map variant. Empty ones contribute via len().
    sum = sum + m1["x"] + m2["z"] + m3["q"] + len(m4)
    sum = sum + m5["y"] + len(m6) + m7["x"] + len(m8)

    // Touch every slice variant. Empty / zero-filled ones via len() or known-zero index.
    sum = sum + len(s1) + s2[2] + s3[1] + len(s4)
    sum = sum + s5[0] + len(s6) + s7[1] + len(s8)

    if sum > 0 {
        log.Println("allocation ok")
    }
}
