// `run greet()` lowers to a real OS thread launching greet().
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
