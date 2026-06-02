package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// Yesterday — at midnight.
	var y time.Time = time.Yesterday()
	if y.Hour() == 0 { pass = pass + 1 }
	if y.Minute() == 0 { pass = pass + 1 }
	if y.Second() == 0 { pass = pass + 1 }

	// Tomorrow — at midnight.
	var t time.Time = time.Tomorrow()
	if t.Hour() == 0 { pass = pass + 1 }
	if t.Minute() == 0 { pass = pass + 1 }
	if t.Second() == 0 { pass = pass + 1 }

	// Yesterday is in the past.
	var y2 time.Time = time.Yesterday()
	if y2.IsPast() { pass = pass + 1 }

	// Tomorrow is in the future.
	var t2 time.Time = time.Tomorrow()
	if t2.IsFuture() { pass = pass + 1 }

	// Tomorrow - Yesterday = 2 days exactly (in nanoseconds).
	var y3 time.Time = time.Yesterday()
	var t3 time.Time = time.Tomorrow()
	var diffNs int = t3.Sub(y3)
	if diffNs == 2 * 86400 * 1000000000 { pass = pass + 1 }

	// Today - Yesterday = 1 day.
	var today time.Time = time.Today()
	var y4 time.Time = time.Yesterday()
	if today.Sub(y4) == 86400 * 1000000000 { pass = pass + 1 }

	// Tomorrow - Today = 1 day.
	var today2 time.Time = time.Today()
	var t4 time.Time = time.Tomorrow()
	if t4.Sub(today2) == 86400 * 1000000000 { pass = pass + 1 }

	// time.Yesterday() equals Today().Yesterday() (the method form).
	var todayBase time.Time = time.Today()
	var viaMethod time.Time = todayBase.Yesterday()
	var freeYest time.Time = time.Yesterday()
	if freeYest.Equal(viaMethod) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
