package main
import "log"
import "testing"
import "errors"

// Positive test: testing.AssertEqInt / AssertEqString / AssertTrue
// / AssertFalse / AssertNil / AssertNotNil. Each returns a bool
// indicating pass/fail so callers can short-circuit.

fun main() int {
	var pass int = 0

	// Use a fresh T value so failures here don't poison the run.
	var t *testing.T = testing.NewT("smoke")

	// AssertEqInt: equal.
	if testing.AssertEqInt(t, 42, 42) { pass = pass + 1 }
	if !t.Failed() { pass = pass + 1 }

	// AssertEqString: equal.
	if testing.AssertEqString(t, "hi", "hi") { pass = pass + 1 }

	// AssertTrue: true cond.
	if testing.AssertTrue(t, 1 < 2) { pass = pass + 1 }

	// AssertFalse: false cond.
	if testing.AssertFalse(t, 5 == 6) { pass = pass + 1 }

	// AssertNil: nil error.
	var e error = nil
	if testing.AssertNil(t, e) { pass = pass + 1 }

	// AssertNotNil: non-nil error.
	var e2 error = errors.New("boom")
	if testing.AssertNotNil(t, e2) { pass = pass + 1 }

	if !t.Failed() { pass = pass + 1 }

	// Use a separate T to test failure propagation.
	var t2 *testing.T = testing.NewT("fail-check")
	if !testing.AssertEqInt(t2, 1, 2) { pass = pass + 1 }
	if t2.Failed() { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 10 { ret 42 }
	ret 0
}
