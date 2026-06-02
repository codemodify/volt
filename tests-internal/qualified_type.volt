// Qualified type names in parameter / receiver / var positions —
// `pkg.Type`. The parser drops the qualifier (volt's type namespace
// is global), but accepting the syntax lets users write Go-style
// signatures.

package main

import "testing"
import "log"

fun checkA(t *testing.T) {
    if 1 + 1 != 2 { t.Error("math broke") }
}

fun checkB(t *testing.T) {
    if "ab" + "c" != "abc" { t.Error("concat broke") }
}

fun main() int {
    var passed int = 0
    if testing.Run("TestArith", checkA) { passed = passed + 1 }
    if testing.Run("TestConcat", checkB) { passed = passed + 1 }
    log.Println("passed=%d/2", passed)
    if passed == 2 { ret 42 }
    ret 0
}
