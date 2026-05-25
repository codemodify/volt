// os.Exit(code) — ergonomic wrapper over syscall.Exit. Lowers to the
// same volt_exit runtime call; the os package is the user-facing name
// (matches Go's os.Exit).

package main

import "log"
import "os"

fun main() {
    log.Println("os.Exit ok")
    os.Exit(42)
}
