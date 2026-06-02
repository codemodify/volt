// Tests in the `fun TestX(t *T)` convention with NO user-defined main.
// This file is meant for `volt test tests-internal/testing_discover.volt`
// — the regression scripts skip it because there's no main yet. But
// `volt build` falls through to the test discovery path: smoke.sh
// won't build it without a `main`, so we provide a stub main that just
// invokes the harness directly. The auto-discovery code path is also
// exercised by `volt test` against this file.

package main

import "testing"

fun TestDoubling(t *T) {
    if 2 * 2 != 4 { t.Error("2*2 != 4") }
    if 3 * 3 != 9 { t.Error("3*3 != 9") }
}

fun TestModulo(t *T) {
    if 7 % 3 != 1 { t.Error("7%3 != 1") }
}

fun main() int {
    var ok bool = true
    if !testing.Run("TestDoubling", TestDoubling) { ok = false }
    if !testing.Run("TestModulo", TestModulo) { ok = false }
    if ok { ret 42 }
    ret 0
}
