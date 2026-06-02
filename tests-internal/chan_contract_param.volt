package main
import "log"

// Positive test: channel multiplicity contracts on function parameters
// are now enforced (C18). A `chanN1 int` parameter means globally one
// writer; this function uses the channel as a writer exactly once,
// satisfying the at-most-1 cap from within this function's scope (the
// caller may contribute additional endpoints we can't see, so we only
// reject DEFINITE violations from the callee side).

fun helper(ch chanN1 int) {
	write(ch, 7)
}

fun reader(ch chan read int, done chan write int) {
	var v int = read(ch)
	write(done, v)
}

fun main() int {
	var ch chanN1 int = new(2)
	var done chan int = new(1)
	run helper(ch)
	run reader(ch, done)
	var v int = read(done)
	log.Println("v=%d", v)
	if v == 7 { ret 42 }
	ret 0
}
