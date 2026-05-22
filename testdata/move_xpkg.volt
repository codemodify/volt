// Negative test: use-after-move across packages.
// log.Println takes (s string) by value, so the first call moves `s`.
// The second call should be caught by the borrow checker now that
// cross-package signatures are loaded.

package main

import "log"

fun main() int {
    var s string = "hello"
    log.Println(s)
    log.Println(s)
    ret 0
}
