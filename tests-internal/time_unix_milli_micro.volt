package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// Epoch.
	var t0 time.Time = time.FromNano(0)
	if t0.UnixMilli() == 0 { pass = pass + 1 }
	if t0.UnixMicro() == 0 { pass = pass + 1 }

	// 1 second.
	var t1 time.Time = time.FromNano(1000000000)
	if t1.UnixMilli() == 1000 { pass = pass + 1 }
	if t1.UnixMicro() == 1000000 { pass = pass + 1 }
	if t1.Unix() == 1 { pass = pass + 1 }

	// 1 millisecond.
	var t2 time.Time = time.FromNano(1000000)
	if t2.UnixMilli() == 1 { pass = pass + 1 }
	if t2.UnixMicro() == 1000 { pass = pass + 1 }

	// 1 microsecond.
	var t3 time.Time = time.FromNano(1000)
	if t3.UnixMilli() == 0 { pass = pass + 1 }    // truncates
	if t3.UnixMicro() == 1 { pass = pass + 1 }

	// Known Time (2025-01-01 UTC = 1735689600 sec = 1735689600000 ms).
	var t4 time.Time = time.Date(2025, 1, 1, 0, 0, 0, 0)
	if t4.UnixMilli() == 1735689600000 { pass = pass + 1 }
	if t4.UnixMicro() == 1735689600000000 { pass = pass + 1 }
	if t4.Unix() == 1735689600 { pass = pass + 1 }

	// Round-trip: FromUnixMs(ms).UnixMilli() == ms.
	var t5 time.Time = time.FromUnixMs(1234567890123)
	if t5.UnixMilli() == 1234567890123 { pass = pass + 1 }

	// Round-trip: FromUnixUs(us).UnixMicro() == us.
	var t6 time.Time = time.FromUnixUs(987654321000000)
	if t6.UnixMicro() == 987654321000000 { pass = pass + 1 }

	// Consistency: nano / 1000 == micro, nano / 1000000 == milli.
	var t7 time.Time = time.Date(2024, 6, 15, 12, 30, 45, 123456789)
	if t7.UnixNano() / 1000 == t7.UnixMicro() { pass = pass + 1 }
	if t7.UnixNano() / 1000000 == t7.UnixMilli() { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
