// =====================================================================
// multi-return.volt — multi-return and "maybe-absent"
// =====================================================================
// volt has no `?T`, no nil for `*T`/`&T`. To express "the answer might be
// absent", return (T, bool) or (T, error). The cost: every type needs a
// sensible zero value for the "absent" return slot.
//
// Functions may return multiple values; callers must bind them via
// `a, b := f()` (short decl) or `a, b = f()` (assignment).
//
//   volt run docs/design/multi-return.volt

package main

import "log"

// divmod returns both quotient and remainder.
fun divmod(a int, b int) (int, int) {
    ret a / b, a % b
}

// findUser is the "maybe-absent" pattern: (value, ok).
fun findUser(id int) (int, bool) {
    if id == 0 {
        ret 0, false
    }
    ret id + 100, true
}

fun main() {
    // ---- Plain multi-return -----------------------------------------------
    q, r := divmod(17, 5)
    if q == 3 && r == 2 {
        log.Println("multi-return ok")
    }

    // ---- "Maybe-absent" pattern -------------------------------------------
    v, ok := findUser(42)
    if ok && v == 142 {
        log.Println("maybe-absent ok")
    }

    _, missing := findUser(0)
    if !missing {
        log.Println("absent ok")
    }
}
