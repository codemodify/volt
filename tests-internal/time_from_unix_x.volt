package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// FromUnixSec — epoch.
	var t0 time.Time = time.FromUnixSec(0)
	if t0.Year() == 1970 { pass = pass + 1 }
	if t0.Month() == 1 { pass = pass + 1 }
	if t0.Day() == 1 { pass = pass + 1 }
	if t0.UnixNano() == 0 { pass = pass + 1 }

	// FromUnixSec — known timestamp: 1735689600 = 2025-01-01 00:00:00 UTC.
	var t1 time.Time = time.FromUnixSec(1735689600)
	if t1.Year() == 2025 { pass = pass + 1 }
	if t1.Month() == 1 { pass = pass + 1 }
	if t1.Day() == 1 { pass = pass + 1 }
	if t1.Hour() == 0 { pass = pass + 1 }

	// FromUnixSec — known second: 1640995200 = 2022-01-01 UTC.
	var t2 time.Time = time.FromUnixSec(1640995200)
	if t2.Year() == 2022 { pass = pass + 1 }
	if t2.Day() == 1 { pass = pass + 1 }

	// Round-trip via .Unix().
	var t3 time.Time = time.FromUnixSec(1234567890)
	if t3.Unix() == 1234567890 { pass = pass + 1 }

	// FromUnixMs.
	var t4 time.Time = time.FromUnixMs(0)
	if t4.UnixNano() == 0 { pass = pass + 1 }
	var t5 time.Time = time.FromUnixMs(1735689600000)
	if t5.Year() == 2025 { pass = pass + 1 }
	if t5.Month() == 1 { pass = pass + 1 }
	if t5.Day() == 1 { pass = pass + 1 }

	// ms precision preserved: 500ms past epoch.
	var t6 time.Time = time.FromUnixMs(500)
	if t6.UnixNano() == 500000000 { pass = pass + 1 }

	// FromUnixUs.
	var t7 time.Time = time.FromUnixUs(1000)
	if t7.UnixNano() == 1000000 { pass = pass + 1 }     // 1ms = 1000us = 1_000_000ns

	// FromUnixUs(1) → 1 microsecond past epoch.
	var t8 time.Time = time.FromUnixUs(1)
	if t8.UnixNano() == 1000 { pass = pass + 1 }

	// Cross-check: FromUnixSec(1) and FromUnixMs(1000) and FromUnixUs(1000000)
	// all give the same instant.
	var s1 time.Time = time.FromUnixSec(1)
	var m1 time.Time = time.FromUnixMs(1000)
	var u1 time.Time = time.FromUnixUs(1000000)
	if s1.UnixNano() == m1.UnixNano() { pass = pass + 1 }
	if m1.UnixNano() == u1.UnixNano() { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
