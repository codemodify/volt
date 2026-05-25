// defer fires at function exit in LIFO order.
// Each call to bump increments a counter we then return.
// Expected: counter ends at 3 → exit 3.

package main

import "log"

fun annotate(s string) {
    log.Println(s)
}

fun main() int {
    def annotate("third")
    def annotate("second")
    def annotate("first")
    ret 3
}
