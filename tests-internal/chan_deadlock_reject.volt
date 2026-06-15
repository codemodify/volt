// #7 stage 1 (static deadlock detection): EXPECTED-NEGATIVE.
//
// `ch` is an unbuffered channel (`new()`, cap=0). A write on it is a
// rendezvous — it blocks until a DIFFERENT thread reads. But `ch` never
// reaches another thread (no `run` spawns it, it's never passed out), so
// the write can never be paired and the program would hang forever.
// The compiler proves this and rejects it. Buffer with `new(N)` or spawn
// the reader with `run` to fix.

package main

fun main() int {
	var ch chan int = new()
	write(ch, 1) // deadlock: no reader can ever exist
	ret 0
}
