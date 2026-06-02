package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// SinceTime — t in the past gives positive elapsed.
	var past time.Time = time.Date(2020, 1, 1, 0, 0, 0, 0)
	var elapsed int = time.SinceTime(past)
	if elapsed > 0 { pass = pass + 1 }
	// Should be at least ~5 years ago in ns terms.
	if elapsed > 5 * 365 * 86400 * 1000000000 { pass = pass + 1 }

	// UntilTime — t in the future gives positive remaining.
	var future time.Time = time.Date(2100, 1, 1, 0, 0, 0, 0)
	var remaining int = time.UntilTime(future)
	if remaining > 0 { pass = pass + 1 }

	// SinceTime/UntilTime should be negatives of each other (modulo
	// the few-ns Now() drift between the two calls — assert within
	// 1ms slack).
	var t1 time.Time = time.Date(2024, 6, 15, 12, 0, 0, 0)
	var s int = time.SinceTime(t1)
	var u int = time.UntilTime(t1)
	var sum int = s + u
	if sum >= -1000000 { pass = pass + 1 }    // ≤ 1ms drift
	if sum <= 1000000 { pass = pass + 1 }

	// SinceTime on a Time near now (within 1s).
	var nowT time.Time = time.FromNano(time.Now())
	var nearZero int = time.SinceTime(nowT)
	if nearZero >= 0 { pass = pass + 1 }
	if nearZero < 1000000000 { pass = pass + 1 }   // < 1s

	// UntilTime on a future +1h time is approximately +1h.
	var oneHourLater time.Time = time.FromNano(time.Now() + 3600 * 1000000000)
	var untilHour int = time.UntilTime(oneHourLater)
	if untilHour > 0 { pass = pass + 1 }
	if untilHour <= 3600 * 1000000000 { pass = pass + 1 }
	if untilHour >= 3500 * 1000000000 { pass = pass + 1 }   // wide slack

	// SinceTime on a future Time is negative.
	var future2 time.Time = time.FromNano(time.Now() + 1000 * 1000000000)   // 1000s ahead
	var elapsedFuture int = time.SinceTime(future2)
	if elapsedFuture < 0 { pass = pass + 1 }

	// UntilTime on a past Time is negative.
	var pastUntil int = time.UntilTime(past)
	if pastUntil < 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
