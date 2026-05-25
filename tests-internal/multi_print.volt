// Test: multiple log.Println calls.
// Expected: three lines printed in order.

package main

import "log"

fun main() {
    log.Println("first")
    log.Println("second")
    log.Println("third")
}
