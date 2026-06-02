// Race-detector smoke test (positive case): properly synchronized
// program should NOT trigger any race warnings under `-race`.
// This file is built and run normally (no -race) for the standard
// regression — it just needs to exit 42. The -race detection
// behavior is exercised by a separate smoke script that runs this
// with `volt run -race` and asserts no WARNING line appears.
package main
import "log"

fun bumper(m mutex int, done chan int) {
	for i := 0; i < 100; i++ {
		var v int = m.Lock()
		v = v + 1
	}
	write(done, 1)
}

fun main() int {
	var m mutex int = new {}
	var done chan int = new(2) chan int
	run bumper(m, done)
	run bumper(m, done)
	read(done)
	read(done)
	var final int = m.Lock()
	log.Println("final=%d", final)
	if final == 200 { ret 42 }
	ret 0
}
