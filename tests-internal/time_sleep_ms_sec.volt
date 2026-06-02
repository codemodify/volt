package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// SleepMs(10) sleeps approximately 10ms. We verify monotonically
	// that Mono() advances by at least 10ms (10_000_000 ns), with a
	// generous upper bound (50ms) to allow for scheduler jitter.
	var t0 int = time.Mono()
	time.SleepMs(10)
	var t1 int = time.Mono()
	var elapsed int = t1 - t0
	if elapsed >= 10000000 { pass = pass + 1 }      // ≥ 10ms
	if elapsed < 100000000 { pass = pass + 1 }      // < 100ms (jitter slack)

	// SleepMs(0) is a no-op — at most a few-ns overhead.
	var t2 int = time.Mono()
	time.SleepMs(0)
	var t3 int = time.Mono()
	if t3 - t2 < 1000000 { pass = pass + 1 }        // < 1ms

	// SleepMs(-5) is also a no-op.
	var t4 int = time.Mono()
	time.SleepMs(-5)
	var t5 int = time.Mono()
	if t5 - t4 < 1000000 { pass = pass + 1 }

	// SleepSec(0) is no-op.
	var t6 int = time.Mono()
	time.SleepSec(0)
	var t7 int = time.Mono()
	if t7 - t6 < 1000000 { pass = pass + 1 }

	// SleepSec(-1) is also no-op.
	var t8 int = time.Mono()
	time.SleepSec(-1)
	var t9 int = time.Mono()
	if t9 - t8 < 1000000 { pass = pass + 1 }

	// 5 short sleeps accumulate roughly to 5*10=50ms minimum.
	var s0 int = time.Mono()
	for i := 0; i < 5; i++ {
		time.SleepMs(10)
	}
	var s1 int = time.Mono()
	if s1 - s0 >= 50000000 { pass = pass + 1 }      // ≥ 50ms total
	if s1 - s0 < 500000000 { pass = pass + 1 }      // < 500ms

	log.Println("pass=%d", pass)
	if pass == 8 { ret 42 }
	ret 0
}
