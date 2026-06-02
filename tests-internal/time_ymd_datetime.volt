package main
import "log"
import "time"

// Positive test: (t Time).YMD + (t Time).Datetime.

fun main() int {
	var pass int = 0

	var t time.Time = time.Date(2024, 3, 15, 14, 30, 45, 0)

	// YMD.
	var y int = 0
	var m int = 0
	var d int = 0
	y, m, d = t.YMD()
	if y == 2024 { pass = pass + 1 }
	if m == 3 { pass = pass + 1 }
	if d == 15 { pass = pass + 1 }

	// Datetime.
	var dy int = 0
	var dm int = 0
	var dd int = 0
	var dh int = 0
	var dmi int = 0
	var ds int = 0
	dy, dm, dd, dh, dmi, ds = t.Datetime()
	if dy == 2024 { pass = pass + 1 }
	if dm == 3 { pass = pass + 1 }
	if dd == 15 { pass = pass + 1 }
	if dh == 14 { pass = pass + 1 }
	if dmi == 30 { pass = pass + 1 }
	if ds == 45 { pass = pass + 1 }

	// YMD epoch — 1970-01-01.
	var ep time.Time = time.FromNano(0)
	y, m, d = ep.YMD()
	if y == 1970 { pass = pass + 1 }
	if m == 1 { pass = pass + 1 }
	if d == 1 { pass = pass + 1 }

	// Datetime midnight.
	var midn time.Time = time.Date(2025, 12, 31, 0, 0, 0, 0)
	dy, dm, dd, dh, dmi, ds = midn.Datetime()
	if dy == 2025 { pass = pass + 1 }
	if dm == 12 { pass = pass + 1 }
	if dd == 31 { pass = pass + 1 }
	if dh == 0 { pass = pass + 1 }
	if dmi == 0 { pass = pass + 1 }
	if ds == 0 { pass = pass + 1 }

	// Datetime end of day.
	var eod time.Time = time.Date(2024, 6, 15, 23, 59, 59, 0)
	dy, dm, dd, dh, dmi, ds = eod.Datetime()
	if dh == 23 { pass = pass + 1 }
	if dmi == 59 { pass = pass + 1 }
	if ds == 59 { pass = pass + 1 }

	// YMD consistency with Datetime.
	y, m, d = t.YMD()
	dy, dm, dd, dh, dmi, ds = t.Datetime()
	if y == dy { pass = pass + 1 }
	if m == dm { pass = pass + 1 }
	if d == dd { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
