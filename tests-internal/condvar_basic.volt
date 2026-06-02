// C10 condvar smoke test: producer/consumer coordination via
// Wait/Signal. Consumer waits for state to flip; producer
// flips state and signals. Use Broadcast version too.
package main
import "log"

fun consumer(c condvar, m mutex int, done chan write int) {
	var p int = m.Lock()
	for p == 0 {
		c.Wait(m)
	}
	write(done, p)
}

fun producer(c condvar, m mutex int) {
	var _p int = m.Lock()
	_p = 42
	if _p == 42 {
		c.Signal()
	}
}

fun broadcastDemo(c condvar, m mutex int, done chan write int) {
	var p int = m.Lock()
	for p == 0 {
		c.Wait(m)
	}
	write(done, p * 2)
}

fun main() int {
	// 1. Signal: one waiter, one signaler.
	var c condvar = new()
	var m mutex int = new {}
	var done chan int = new(1) chan int
	run consumer(c, m, done)
	// Let consumer get to the Wait. Without a sleep primitive we just
	// rely on the OS scheduler — typical setup for this pattern.
	run producer(c, m)
	var result int = read(done)
	if result != 42 { ret 1 }

	// 2. Broadcast: multiple waiters, one broadcaster wakes them all.
	var c2 condvar = new()
	var m2 mutex int = new {}
	var done2 chan int = new(3) chan int
	run broadcastDemo(c2, m2, done2)
	run broadcastDemo(c2, m2, done2)
	run broadcastDemo(c2, m2, done2)
	// Update state and broadcast inside a nested block so the guard
	// auto-releases m2 BEFORE main waits on done2 (otherwise waiters
	// would deadlock trying to reacquire the lock after their wake).
	// Wrap in `if true { ... }` since volt doesn't have bare blocks.
	if 1 < 2 {
		var _p2 int = m2.Lock()
		_p2 = 7
		if _p2 == 7 {
			c2.Broadcast()
		}
	}
	var sum int = read(done2) + read(done2) + read(done2)
	// Each waiter computes p2 * 2 = 14; three readers → 42
	if sum != 42 { ret 2 }

	log.Println("ok")
	ret 42
}
