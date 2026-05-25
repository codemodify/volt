// Test: user-defined function called from main.

package main

import "log"

fun greet() {
    log.Println("hello from greet")
}

fun main() {
    greet()
}
