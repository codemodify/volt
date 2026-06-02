package main
import "log"
import "time"

// Positive test: time.UnixMs / UnixUs / MonoMs / MonoUs — convenience
// wrappers around Now() and Mono() that divide by the unit factor.

fun main() int {
	var pass int = 0

	// UnixMs / UnixUs are wall-clock-based. They should be > 0
	// (the Unix epoch is in 1970; we're after that).
	var ms int = time.UnixMs()
	var us int = time.UnixUs()
	if ms > 0 { pass = pass + 1 }
	if us > 0 { pass = pass + 1 }
	// us is 1000x larger than ms (or close to it — they're sampled
	// at slightly different moments, but the ratio should hold to
	// within 1).
	if us / 1000 == ms { pass = pass + 1 } else { if (us / 1000) - ms <= 1 { pass = pass + 1 } else { if ms - (us / 1000) <= 1 { pass = pass + 1 } } }

	// MonoMs / MonoUs are process-relative; both ≥ 0.
	var mms int = time.MonoMs()
	var mus int = time.MonoUs()
	if mms >= 0 { pass = pass + 1 }
	if mus >= 0 { pass = pass + 1 }
	// us is 1000x larger.
	if mus >= mms * 1000 { pass = pass + 1 }

	// Sanity: MonoMs is much smaller than UnixMs (process started
	// well after the 1970 epoch).
	if mms < ms { pass = pass + 1 }

	// Sleep 5ms, MonoMs should advance by ≥ 5.
	var before int = time.MonoMs()
	time.Sleep(5 * time.Millisecond)
	var after int = time.MonoMs()
	if after - before >= 5 { pass = pass + 1 }
	// Cap upper bound generously (test env may be slow).
	if after - before < 1000 { pass = pass + 1 }

	log.Println("pass=%d ms=%d mms=%d", pass, ms, mms)
	if pass == 9 { ret 42 }
	ret 0
}
