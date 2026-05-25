// =====================================================================
// defer.volt — `def`, the only user-visible cleanup mechanism
// =====================================================================
// volt has no exceptions and no automatic destructors for user-defined
// state. (The compiler frees MEMORY at scope exit automatically; that
// is invisible.)
//
// `def expr` registers `expr` — typically a call — to run when the
// surrounding function exits. Deferred calls fire in LIFO order: the
// last `def` runs first.
//
// Use def for user-visible side-effects: closing files, releasing
// locks, "I'm done" log lines, etc.
//
//   volt run docs/design/defer.volt

package main

import "log"

fun annotate(s string) {
    log.Println(s)
}

fun main() {
    def annotate("defer: 3rd-registered (runs FIRST)")
    def annotate("defer: 2nd-registered")
    def annotate("defer: 1st-registered (runs LAST)")

    log.Println("body: doing the actual work")
    log.Println("body: about to return — defers fire next")
}
