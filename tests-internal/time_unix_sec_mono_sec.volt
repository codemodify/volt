package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// UnixSec — positive (assuming clock is post-1970, which holds
	// for any modern Linux test environment).
	var sec int = time.UnixSec()
	if sec > 0 { pass = pass + 1 }

	// UnixSec — must be smaller than UnixMs / UnixUs / Now (more
	// precision means a larger integer for the same instant).
	var ms int = time.UnixMs()
	var us int = time.UnixUs()
	var ns int = time.Now()
	if sec <= ms { pass = pass + 1 }
	if ms <= us { pass = pass + 1 }
	if us <= ns { pass = pass + 1 }

	// UnixSec — multiplying back by 1e9 should land within one
	// second of `Now()` (modulo sub-second truncation).
	var diff int = ns - sec * 1000000000
	if diff >= 0 { pass = pass + 1 }
	if diff < 1000000000 { pass = pass + 1 }

	// MonoSec — non-negative; relation to MonoMs / MonoUs / Mono.
	var msec int = time.MonoSec()
	var mms int = time.MonoMs()
	var mus int = time.MonoUs()
	var mns int = time.Mono()
	if msec >= 0 { pass = pass + 1 }
	if msec <= mms { pass = pass + 1 }
	if mms <= mus { pass = pass + 1 }
	if mus <= mns { pass = pass + 1 }

	// MonoSec — back-multiply within one second of Mono().
	var mdiff int = mns - msec * 1000000000
	if mdiff >= 0 { pass = pass + 1 }
	if mdiff < 1000000000 { pass = pass + 1 }

	// UnixSec >= some sanity-floor (2021-01-01 = 1609459200) so we
	// don't accidentally pass on a zero-Now() stub.
	if sec > 1609459200 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
