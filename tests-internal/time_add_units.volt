package main
import "log"
import "time"

// Positive test: (t Time).AddMillis + AddSeconds + AddMinutes + AddHours.

fun main() int {
	var pass int = 0

	var t0 time.Time = time.Date(2024, 3, 15, 12, 0, 0, 0)

	// AddMillis — 1500ms forward (1.5s).
	var tm time.Time = t0.AddMillis(1500)
	if tm.SecondsBetween(t0) == 1 { pass = pass + 1 }   // floor-div: 1500ms = 1 sec

	// AddSeconds — +60 seconds == +1 minute.
	var ts time.Time = t0.AddSeconds(60)
	if ts.SecondsBetween(t0) == 60 { pass = pass + 1 }
	if ts.MinutesBetween(t0) == 1 { pass = pass + 1 }

	// AddSeconds — negative direction.
	var tsn time.Time = t0.AddSeconds(-30)
	if tsn.SecondsBetween(t0) == -30 { pass = pass + 1 }

	// AddMinutes — +30 minutes.
	var tmin time.Time = t0.AddMinutes(30)
	if tmin.MinutesBetween(t0) == 30 { pass = pass + 1 }
	if tmin.SecondsBetween(t0) == 1800 { pass = pass + 1 }

	// AddMinutes — +60 == +1 hour.
	var tmin60 time.Time = t0.AddMinutes(60)
	if tmin60.HoursBetween(t0) == 1 { pass = pass + 1 }

	// AddHours — +24 == +1 day.
	var th time.Time = t0.AddHours(24)
	if th.HoursBetween(t0) == 24 { pass = pass + 1 }
	if th.DaysBetween(t0) == 1 { pass = pass + 1 }

	// AddHours — negative.
	var thn time.Time = t0.AddHours(-3)
	if thn.HoursBetween(t0) == -3 { pass = pass + 1 }

	// AddMillis — +1000ms == +1 sec.
	var tms time.Time = t0.AddMillis(1000)
	if tms.SecondsBetween(t0) == 1 { pass = pass + 1 }

	// AddMillis — sub-second granular.
	var tms250 time.Time = t0.AddMillis(250)
	if tms250.SecondsBetween(t0) == 0 { pass = pass + 1 }   // floor < 1 sec

	// Chained: add a minute then add an hour.
	var ch time.Time = t0.AddMinutes(1).AddHours(1)
	if ch.MinutesBetween(t0) == 61 { pass = pass + 1 }

	// AddSeconds(0) returns same instant.
	var same time.Time = t0.AddSeconds(0)
	if same.SecondsBetween(t0) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
