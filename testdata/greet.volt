// v0.3 test: string passed through user function, then to log.Println.
// Output: "Alice" then "Bob" on stderr; exit 0.

package main

import "log"

fun greet(name string) {
    log.Println(name)
}

fun main() int {
    greet("Alice")
    greet("Bob")
    ret 0
}
