// term: Size/MakeRaw/Restore/PollIn link and run without crashing, and
// return sane values even when stdin/stdout is NOT a terminal (as under
// the test harness, where they're pipes). Size falls back to 24x80;
// MakeRaw fails gracefully (negative) on a non-tty; Restore is a safe
// no-op; PollIn(0) on an empty/closed pipe does not block.
package main

import "fmt"
import "term"
import "strconv"

fun main() int {
    var pass int = 0

    var rows int = 0
    var cols int = 0
    rows, cols = term.Size()
    // Always positive thanks to the 24x80 fallback.
    if rows > 0 { pass = pass + 1 }
    if cols > 0 { pass = pass + 1 }

    // MakeRaw on a non-tty returns a negative errno; on a tty it returns
    // 0. Either way it must not crash. Restore is always safe to call.
    var r int = term.MakeRaw()
    if r <= 0 { pass = pass + 1 }     // 0 (tty) or -errno (pipe)
    term.Restore()
    pass = pass + 1                   // reached here = Restore didn't crash

    // PollIn(0) is non-blocking — must return promptly regardless of tty.
    var ready bool = term.PollIn(0)
    if ready || !ready { pass = pass + 1 }   // tautology: proves it returned

    fmt.Println("rows=" + strconv.Itoa(rows) + " cols=" + strconv.Itoa(cols) + " makeraw=" + strconv.Itoa(r))
    fmt.Println("pass=" + strconv.Itoa(pass))
    if pass == 5 { ret 42 }
    ret 1
}
