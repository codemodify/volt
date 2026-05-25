// =====================================================================
// 2-ownership.volt — runnable examples of the ownership model
// =====================================================================
// For the model itself (T / &T / *T, MOVE / COPY / SHARE per type,
// volt vs C vs Go), see docs/design/2-ownership.md.
//
//   volt run docs/design/2-ownership.volt

package main

import "log"

// =====================================================================
// 1. Primitives
// =====================================================================

fun primitivesCopy(n int) {
    log.Println("primitivesCopy n=%d", n)
}

fun primitivesRead(n &int) {
    log.Println("primitivesRead n=%d", n)
}

fun primitivesWrite(n *int) {
    n = n + 1
    log.Println("primitivesWrite n=%d", n)
}

fun primitivesBadWrite(n &int) {
    n = n + 1                            // fail: write through `&T` (read-only)
}

fun primitives() {
    var v int = 10

    primitivesCopy(v)                    // copy         -> 10  (v still 10)
    primitivesRead(v)                    // read access  -> 10  (v still 10)
    v = v + 1                            //                     (v = 11)
    primitivesWrite(v)                   // write access -> 12  (v becomes 12)

    log.Println("v=%d", v)               // -> 12
}

// =====================================================================
// 2. Structs
// =====================================================================
// Method-receiver types follow the same three forms as parameter types
// (Counter, &Counter, *Counter).

type Counter struct {
    value int
}

fun consume(c Counter) {
    log.Println("consume value=%d", c.value)
}

fun (c &Counter) Read() int {
    ret c.value
}

fun (c *Counter) Bump() {
    c.value = c.value + 1
}

fun (c &Counter) BadWrite() {
    c.value = 99                         // fail: write through `&T` (read-only)
}

fun structs() {
    var c Counter = new Counter{value: 10}

    c.Bump()                             // write access -> c.value = 11
    c.Bump()                             // write access -> c.value = 12

    var a int = c.Read()                 // read access  -> 12
    var b int = c.Read()                 // read access  -> 12 (many readers OK)
    log.Println("a=%d b=%d c.value=%d", a, b, c.value)

    // To keep the original alive across a move, clone it first.
    var survivor Counter = new Counter{value: 7}
    consume(clone(survivor))             // pass an independent copy
    log.Println("survivor alive: %d", survivor.value)
}

// useAfterMove demonstrates that reading a moved value is rejected.
// Declared but never called — the compiler refuses to build the body.
fun useAfterMove() {
    var dead Counter = new Counter{value: 99}
    consume(dead)                        // move: ownership transferred
    log.Println("dead=%d", dead.value)   // fail: use after move
}

// =====================================================================
// 3. Lifetime
// =====================================================================
// A reader/writer cannot outlive the value it points at. Returning
// access to a PARAMETER is fine (the parameter outlives the call).
// Returning access to a LOCAL is rejected — the local dies when the
// function returns, so the access would dangle.

fun keep(c &Counter) &Counter {
    ret c                                // ok: parameter outlives the call
}

fun makeAndLeak() &Counter {
    var local Counter = new Counter{value: 1}
    ret local                            // fail: read-access to local would outlive owner
}

fun main() {
    primitives()
    structs()
    log.Println("ownership ok")
}
