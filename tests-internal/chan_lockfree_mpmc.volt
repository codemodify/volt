// D.2 lock-free MPMC channel smoke test (default backend, mutex).
// Verifies that buffered channels handle 3-producer × 2-consumer
// concurrent traffic correctly under the regular mutex backend.
// The same source runs under the lock-free backend via the dedicated
// /tmp/lf_mpmc.volt smoke harness (--channels lockfree).
package main
import "log"

fun producer(ch chan write int, base int, n int, done chan write int) {
	for i := 0; i < n; i++ {
		write(ch, base + i)
	}
	write(done, 1)
}

fun consumer(ch chan read int, total int, sums chan write int) {
	var s int = 0
	for i := 0; i < total; i++ {
		var v int = read(ch)
		s = s + v
	}
	write(sums, s)
}

fun main() int {
	var ch chan int = new(16) chan int
	var done chan int = new(3) chan int
	var sums chan int = new(2) chan int
	run producer(ch, 1000, 100, done)
	run producer(ch, 2000, 100, done)
	run producer(ch, 3000, 100, done)
	run consumer(ch, 150, sums)
	run consumer(ch, 150, sums)
	read(done)
	read(done)
	read(done)
	var s1 int = read(sums)
	var s2 int = read(sums)
	// Sums: A=(1000+1099)*100/2=104950, B=204950, C=304950 → total 614850
	log.Println("total=%d", s1 + s2)
	if s1 + s2 == 614850 { ret 42 }
	ret 0
}
