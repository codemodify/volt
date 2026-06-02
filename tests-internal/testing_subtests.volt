// testing.T.Run for nested subtests. Each subtest gets a hierarchical
// name "parent/sub". Subtest failure marks the parent failed; subtest
// passes leave the parent untouched.

package main

import "testing"
import "log"

fun TestArithmetic(t *T) {
    t.Run("addition", fun(t *T) {
        if 1 + 1 != 2 { t.Error("1+1") }
        if 3 + 4 != 7 { t.Error("3+4") }
    })
    t.Run("multiplication", fun(t *T) {
        if 2 * 3 != 6 { t.Error("2*3") }
    })
    t.Run("division", fun(t *T) {
        if 10 / 2 != 5 { t.Error("10/2") }
    })
}

fun TestMixedFailures(t *T) {
    t.Run("passing", fun(t *T) {
        if 1 != 1 { t.Error("identity broken") }
    })
    t.Run("failing", fun(t *T) {
        t.Error("intentional sub-failure")
    })
}

fun main() int {
    var pass int = 0
    var fail int = 0

    if testing.Run("TestArithmetic", TestArithmetic) { pass = pass + 1 } else { fail = fail + 1 }
    if testing.Run("TestMixedFailures", TestMixedFailures) { pass = pass + 1 } else { fail = fail + 1 }

    log.Println("summary: %d passed, %d failed", pass, fail)

    // Expect: TestArithmetic passes (3 subtests all pass), TestMixedFailures fails
    // (one of two subtests fails → parent is marked failed).
    if pass == 1 {
        if fail == 1 { ret 42 }
    }
    ret 0
}
