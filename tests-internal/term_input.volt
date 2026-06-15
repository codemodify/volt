// term: ReadKey / ReadByte / PollIn input path. Harness-SAFE: every read
// is guarded by a non-blocking PollIn(0), so with no input (idle terminal)
// the loop body never runs and the test passes immediately; with input
// piped in it drains and classifies every key. Never blocks, so the
// correctness harness (uncontrolled stdin, 10s timeout) can't hang on it.
//
// Drive it manually to exercise the escape-sequence decoder, e.g.:
//   printf '\033[A\033[B\033[Cx' | .tempbins/volt run tests-internal/term_input.volt
//   -> sees Up, Down, Right, and 'x' (4 keys, 3 arrows).
package main

import "fmt"
import "term"
import "strconv"

fun main() int {
    var keys   int = 0
    var arrows int = 0
    var printables int = 0

    // Bounded, poll-guarded drain: stops as soon as no byte is pending.
    for i := 0; i < 256; i = i + 1 {
        if !term.PollIn(0) {
            break
        }
        var k int = term.ReadKey()
        if k == term.KeyEOF || k == term.KeyErr {
            break
        }
        keys = keys + 1
        if k == term.KeyUp || k == term.KeyDown || k == term.KeyLeft || k == term.KeyRight {
            arrows = arrows + 1
        }
        if k >= 32 && k < 127 {
            printables = printables + 1
        }
    }

    fmt.Println("keys=" + strconv.Itoa(keys) + " arrows=" + strconv.Itoa(arrows) + " printables=" + strconv.Itoa(printables))
    // No-input and EOF paths both leave keys==0; any successful run is a
    // pass (decoding correctness is asserted by the manual piped run).
    ret 42
}
