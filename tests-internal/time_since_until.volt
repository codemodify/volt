package main
import "log"
import "time"

// Positive test: time.Since(t) / time.Until(t) convenience helpers
// around time.Mono(), plus the new time.Minute / time.Hour duration
// constants.

fun main() int {
	var pass int = 0

	// Constants present and correct (compile-time intrinsics).
	if time.Nanosecond == 1 { pass = pass + 1 }
	if time.Microsecond == 1000 { pass = pass + 1 }
	if time.Millisecond == 1000000 { pass = pass + 1 }
	if time.Second == 1000000000 { pass = pass + 1 }
	if time.Minute == 60000000000 { pass = pass + 1 }
	if time.Hour == 3600000000000 { pass = pass + 1 }

	// Since: elapsed time from a past timestamp is non-negative.
	var start int = time.Mono()
	time.Sleep(time.Millisecond)
	var elapsed int = time.Since(start)
	if elapsed >= time.Millisecond { pass = pass + 1 }
	// Cap upper bound generously (test environment may be slow).
	if elapsed < time.Second { pass = pass + 1 }

	// Until: a future deadline is positive.
	var soon int = time.Mono() + time.Second
	var remaining int = time.Until(soon)
	if remaining > 0 { pass = pass + 1 }
	if remaining <= time.Second { pass = pass + 1 }

	log.Println("pass=%d elapsed=%d remaining=%d", pass, elapsed, remaining)
	if pass == 10 { ret 42 }
	ret 0
}
