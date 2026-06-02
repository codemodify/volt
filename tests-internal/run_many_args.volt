package main
import "log"

// Positive test: `run f(...)` with more than 6 args used to be capped
// by the SysV register-arg ceiling that volt_spawn passes through (6
// ptr-slots). Codegen now synthesizes a struct-pack thunk whenever
// len(sig.Params) > spawnMaxArgs (or any single arg is oversized) —
// pack is heap-allocated, args are stored field-by-field, the thunk
// unpacks and tail-calls f. This test exercises 8 args (7 ints + a
// chan write int handle), which would not fit the 6-slot ceiling.

fun worker(a int, b int, c int, d int, e int, f int, g int, out chan write int) {
	write(out, a + b + c + d + e + f + g)
}

fun main() int {
	var done chan int = new(1)
	run worker(1, 2, 3, 4, 5, 6, 7, done)
	var total int = read(done)
	log.Println("total=%d", total)
	if total == 28 { ret 42 }
	ret 0
}
