package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// Construct a time well in the past — Jan 1 2020.
	var past time.Time = time.Date(2020, 1, 1, 0, 0, 0, 0)
	if past.IsPast() { pass = pass + 1 }
	if !past.IsFuture() { pass = pass + 1 }

	// Far future — Jan 1 2100.
	var future time.Time = time.Date(2100, 1, 1, 0, 0, 0, 0)
	if future.IsFuture() { pass = pass + 1 }
	if !future.IsPast() { pass = pass + 1 }

	// A Time near now — capture Now() and shift by tiny deltas.
	var nowNs int = time.Now()
	var oneHourFromNow time.Time = time.FromNano(nowNs + 3600 * 1000000000)
	if oneHourFromNow.IsFuture() { pass = pass + 1 }
	if !oneHourFromNow.IsPast() { pass = pass + 1 }

	var oneHourAgo time.Time = time.FromNano(nowNs - 3600 * 1000000000)
	if oneHourAgo.IsPast() { pass = pass + 1 }
	if !oneHourAgo.IsFuture() { pass = pass + 1 }

	// Zero time — definitely past (1970-01-01 UTC).
	var zero time.Time = time.FromNano(0)
	if zero.IsPast() { pass = pass + 1 }
	if !zero.IsFuture() { pass = pass + 1 }

	// A time 1s past Now() is definitely future (race-resistant).
	var oneSecLater time.Time = time.FromNano(time.Now() + 1000000000)
	if oneSecLater.IsFuture() { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 11 { ret 42 }
	ret 0
}
