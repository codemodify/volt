// =====================================================================
// producer-consumer.volt — a tiny producer/consumer pipeline
// =====================================================================
// Streams "bytes" from an in-memory counter through a bounded channel
// into a consumer that counts them. Demonstrates: real OS threads
// (`run`), bounded channels, channel close + two-value receive,
// `def` cleanup, time.Sleep.
//
//   volt run tests-custom/producer-consumer.volt

package main

import (
	"log"
	"time"
)

// Number of "bytes" the producer will emit.
const N = 32

// Producer streams N integers (1..N) and closes the channel.
fun producer(out chan int) {
	def log.Println("producer: done")

	var i int = 1
	for i <= N {
		write(out, i)
		i = i + 1
	}
	close(out)
}

// Consumer drains the channel until closed, counts items, sends total.
// Throttles slightly so the producer/consumer don't trivially race to
// completion — exercises the futex-based channel.
fun consumer(in chan int, done chan int) {
	def log.Println("consumer: done")

	var total int = 0
	for {
		v, ok := read(in)
		if !ok {
			write(done, total)
			ret
		}
		total = total + 1
		if v % 8 == 0 {
			log.Println("consumer: hit 8-byte marker at v=%d", v)
		}
		time.Sleep(100 * time.Microsecond)
	}
}

fun main() {
	var ch   chan int = new(8) chan int
	var done chan int = new(1) chan int

	run producer(ch)
	run consumer(ch, done)

	var total int = read(done)
	if total == N {
		log.Println("main: finished, all %d bytes accounted for", total)
	} else {
		log.Println("main: finished, but count mismatch (got %d, expected %d)", total, N)
	}
}
