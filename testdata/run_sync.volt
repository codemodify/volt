// v0.4 Phase 3 (placeholder): `run` lowers to a synchronous call.
// Real concurrency requires the goroutine scheduler (deferred).
// Compiles and runs; greeting prints once.

package main

import "log"

fun greet() {
    log.Println("ran")
}

fun main() int {
    run greet()
    ret 42
}
