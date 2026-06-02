package main
import "log"

// Verifies that the D.1 race-detector runtime stub symbols
// (volt_race_read/write/acquire/release/thread_start/thread_end)
// link cleanly. Doesn't exercise them — codegen does not yet
// emit calls to these symbols. This test exists so a regression
// that removes the stubs gets caught immediately.

fun main() int {
	log.Println("race-runtime stubs linked")
	ret 42
}
