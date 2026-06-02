// testing package smoke test. Run several Test* functions through
// testing.Run, verify pass/fail accounting matches expectations.

package main

import "testing"
import "log"

fun TestAddition(t *T) {
    if 1 + 1 != 2 { t.Error("1+1 != 2") }
    if 2 + 3 != 5 { t.Error("2+3 != 5") }
}

fun TestStringEquality(t *T) {
    if "abc" != "abc" { t.Error("string equality broken") }
    if "abc" == "xyz" { t.Error("string inequality broken") }
}

fun TestThatFails(t *T) {
    t.Error("intentional failure")
}

fun TestThatFatalExits(t *T) {
    t.Fatal("intentional fatal")
}

fun main() int {
    var pass int = 0
    var fail int = 0

    if testing.Run("TestAddition", TestAddition) { pass = pass + 1 } else { fail = fail + 1 }
    if testing.Run("TestStringEquality", TestStringEquality) { pass = pass + 1 } else { fail = fail + 1 }
    if testing.Run("TestThatFails", TestThatFails) { pass = pass + 1 } else { fail = fail + 1 }
    if testing.Run("TestThatFatalExits", TestThatFatalExits) { pass = pass + 1 } else { fail = fail + 1 }

    log.Println("summary: %d passed, %d failed", pass, fail)

    // Expect: 2 passed (Addition, StringEquality), 2 failed (intentional).
    if pass == 2 {
        if fail == 2 { ret 42 }
    }
    ret 0
}
