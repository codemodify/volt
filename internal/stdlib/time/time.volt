// Package time: timing and duration helpers.
//
// Sleep(ns int) blocks the calling thread for at least ns nanoseconds
// via the sys_nanosleep syscall (no libc).
//
// Now() returns nanoseconds since the Unix epoch (CLOCK_REALTIME).
// Mono() returns nanoseconds since process start (CLOCK_MONOTONIC) —
// strictly increasing; the right primitive for elapsed-time measurement.
//
// Time is a value-type wrapper around nanoseconds since epoch. UTC-only
// (no time-zone database in v1). Year/Month/Day decomposition uses
// Howard Hinnant's days-from-civil algorithm. Format produces an
// RFC3339-style string ("2026-05-25T14:30:00Z") — fixed layout in v1;
// Go's magic-number layout parser is future work.
//
// The duration unit identifiers (time.Nanosecond, time.Microsecond,
// time.Millisecond, time.Second) are compile-time integer constants
// expanded by the codegen — they have no storage in this module.
//
// Sleep, Now, and Mono are COMPILER INTRINSICS — the bodies below are
// stand-ins for type-check only.

package time

import "syscall"
import "strconv"
import "errors"
import "bytes"

fun Sleep(ns int) {
    syscall.Nanosleep(ns)
}

// SleepMs blocks for `ms` milliseconds. Convenience over
// `Sleep(ms * 1_000_000)` — matches the precision callers most
// often use for backoff loops, polling intervals, and rate-limit
// pacing. Non-positive ms is a no-op.
fun SleepMs(ms int) {
    if ms <= 0 { ret }
    syscall.Nanosleep(ms * 1000000)
}

// SleepSec blocks for `sec` seconds. Convenience over `Sleep(sec *
// 1_000_000_000)`. Useful for long waits where ns granularity is
// noise (background loops, periodic GC, daily housekeeping).
fun SleepSec(sec int) {
    if sec <= 0 { ret }
    syscall.Nanosleep(sec * 1000000000)
}

fun Now() int { ret 0 }
fun Mono() int { ret 0 }
fun Since(t int) int { ret 0 }
fun Until(t int) int { ret 0 }

// SinceTime returns the elapsed nanoseconds from `t` to the current
// wall-clock time. Positive if t is in the past, zero at "now",
// negative if t is in the future. Equivalent to
// `FromNano(Now()).Sub(t)` but reads more directly at the call
// site. Useful for "how long ago was that?" measurements and
// freshness checks: `if SinceTime(lastSeen) > FormatDuration(5m)`.
fun SinceTime(t Time) int {
    var nowT Time = FromNano(Now())
    ret nowT.Sub(t)
}

// UntilTime returns the nanoseconds from current wall-clock time
// until `t`. Positive if t is in the future, zero at "now",
// negative if t is in the past. Counterpart to SinceTime — useful
// for "time-to-deadline" computations: `remaining := UntilTime(
// expiresAt); if remaining < 0 { ... }`.
fun UntilTime(t Time) int {
    var nowT Time = FromNano(Now())
    ret t.Sub(nowT)
}

// UnixMs returns the current wall-clock time as milliseconds since
// the Unix epoch. Convenience over `Now() / 1_000_000`.
fun UnixMs() int {
    ret Now() / 1000000
}

// UnixUs returns the current wall-clock time as microseconds since
// the Unix epoch.
fun UnixUs() int {
    ret Now() / 1000
}

// UnixSec returns the current wall-clock time as seconds since the
// Unix epoch — the canonical "what time is it" int for log lines,
// rate-limit windows, and DB timestamp columns. Completes the
// `Unix{Sec,Ms,Us}` precision trio over `Now()` (nanoseconds).
fun UnixSec() int {
    ret Now() / 1000000000
}

// MonoMs returns the monotonic clock reading in milliseconds since
// process start. Convenience over `Mono() / 1_000_000`.
fun MonoMs() int {
    ret Mono() / 1000000
}

// MonoUs returns the monotonic clock reading in microseconds.
fun MonoUs() int {
    ret Mono() / 1000
}

// MonoSec returns the monotonic clock reading in seconds since
// process start. Completes the `Mono{Sec,Ms,Us}` precision trio
// over `Mono()` (nanoseconds). Use for long-running elapsed-time
// measurements where wall-clock NTP jumps would corrupt the delta.
fun MonoSec() int {
    ret Mono() / 1000000000
}

// ---- Time value type ------------------------------------------------

type Time struct {
    ns int                          // nanoseconds since Unix epoch (UTC)
}

// Unix constructs a Time from (seconds, nanoseconds) since epoch.
fun Unix(sec int, ns int) Time {
    var t Time = new Time {ns: sec * 1000000000 + ns}
    ret t
}

// FromNano builds a Time directly from nanoseconds since epoch.
fun FromNano(ns int) Time {
    var t Time = new Time {ns: ns}
    ret t
}

// FromUnixSec builds a Time from a Unix-seconds timestamp — the
// canonical "seconds since 1970-01-01 UTC" integer (JWT `iat`/`exp`,
// log lines, DB timestamps stored as seconds). Convenience over
// `Unix(sec, 0)`.
fun FromUnixSec(sec int) Time {
    var t Time = new Time {ns: sec * 1000000000}
    ret t
}

// FromUnixMs builds a Time from a milliseconds-since-epoch
// timestamp (common for JavaScript Date.now, DB timestamp columns,
// telemetry events). Convenience over `Unix(ms / 1000, (ms % 1000) *
// 1000000)`.
fun FromUnixMs(ms int) Time {
    var t Time = new Time {ns: ms * 1000000}
    ret t
}

// FromUnixUs builds a Time from a microseconds-since-epoch
// timestamp (common for high-resolution profilers, syscall traces,
// some database timestamp formats).
fun FromUnixUs(us int) Time {
    var t Time = new Time {ns: us * 1000}
    ret t
}

// Date constructs a UTC Time from civil-calendar components. Month
// is 1..12; day is 1..31 (out-of-range values aren't validated —
// the algorithm carries overflow naturally, but for safety pass
// well-formed values). Mirrors Go's time.Date (in UTC; no Location
// argument since volt-time is UTC-only in v1).
fun Date(year int, month int, day int, hour int, minute int, second int, nanos int) Time {
    var days int = daysFromCivil(year, month, day)
    var secs int = days * 86400 + hour * 3600 + minute * 60 + second
    ret new Time {ns: secs * 1000000000 + nanos}
}

fun (t Time) UnixNano() int { ret t.ns }
fun (t Time) Unix() int     { ret t.ns / 1000000000 }

// UnixMilli returns t as milliseconds since the Unix epoch — the
// per-Time method form parallel to the free `UnixMs()` "now-as-ms"
// function. Useful when you have a Time and need its ms timestamp:
// `t.UnixMilli()` reads more directly than `t.UnixNano() / 1000000`.
fun (t Time) UnixMilli() int { ret t.ns / 1000000 }

// UnixMicro returns t as microseconds since the Unix epoch. Per-Time
// counterpart of the free `UnixUs()` function.
fun (t Time) UnixMicro() int { ret t.ns / 1000 }

// Add returns t shifted by d nanoseconds (d is a Duration / nanos int).
fun (t Time) Add(d int) Time {
    var r Time = new Time {ns: t.ns + d}
    ret r
}

// Sub returns the duration in nanoseconds between t and earlier u.
fun (t Time) Sub(u Time) int { ret t.ns - u.ns }

// Before reports whether t is strictly earlier than u.
fun (t Time) Before(u Time) bool {
    if t.ns < u.ns { ret true }
    ret false
}

// After reports whether t is strictly later than u.
fun (t Time) After(u Time) bool {
    if t.ns > u.ns { ret true }
    ret false
}

// AddDays returns t shifted forward by n days (n may be negative
// for backward shift). Calendar-aware in the sense that 1 day is
// always 86_400 seconds — DST and leap-second nuance are deliberately
// not modeled. Convenience wrapper over t.Add(n * 24h in nanos).
fun AddDays(t Time, n int) Time {
    var d int = n * 86400 * 1000000000
    ret t.Add(d)
}

// AddHours returns t shifted by n hours (negative shifts backward).
// Convenience wrapper over t.Add(n * 1h in nanos).
fun AddHours(t Time, n int) Time {
    var d int = n * 3600 * 1000000000
    ret t.Add(d)
}

// DiffDays returns the number of whole days from u to t (sign-
// preserving). Truncates toward zero — e.g. 36 hours → 1 day.
// Same calendar simplification as AddDays.
fun DiffDays(t Time, u Time) int {
    var nsd int = t.Sub(u)
    ret nsd / (86400 * 1000000000)
}

// DiffHours returns the number of whole hours from u to t (sign-
// preserving). Truncates toward zero.
fun DiffHours(t Time, u Time) int {
    var nsd int = t.Sub(u)
    ret nsd / (3600 * 1000000000)
}

// DiffMinutes returns the number of whole minutes from u to t.
// Sign-preserving, truncates toward zero. Completes the DiffDays/
// DiffHours family for the minute granularity.
fun DiffMinutes(t Time, u Time) int {
    var nsd int = t.Sub(u)
    ret nsd / (60 * 1000000000)
}

// DiffSeconds returns the number of whole seconds from u to t.
// Sign-preserving, truncates toward zero.
fun DiffSeconds(t Time, u Time) int {
    var nsd int = t.Sub(u)
    ret nsd / 1000000000
}

// MinTime returns the earlier of a and b. On equality returns a
// (stable left-bias). Useful for `deadline = MinTime(userDeadline,
// systemMaxDeadline)` and similar bounds-narrowing patterns.
fun MinTime(a Time, b Time) Time {
    if a.ns <= b.ns { ret a }
    ret b
}

// MaxTime returns the later of a and b. On equality returns a
// (stable left-bias). Counterpart to MinTime — useful for
// "earliest-allowed start time" pattern: `start = MaxTime(now,
// scheduledStart)`.
fun MaxTime(a Time, b Time) Time {
    if a.ns >= b.ns { ret a }
    ret b
}

// TimeIsBetween reports whether t falls within the inclusive range
// [lo, hi]. Returns false when lo > hi (degenerate range). Useful
// for "is this timestamp within the audit window?" / "did the event
// happen during business hours?" checks. Boundary values inclusive
// on both ends.
fun TimeIsBetween(t Time, lo Time, hi Time) bool {
    if hi.ns < lo.ns { ret false }
    if t.ns < lo.ns { ret false }
    if t.ns > hi.ns { ret false }
    ret true
}

// EarliestOf returns the earliest Time in `times`. Empty input
// returns the zero Time (`Unix(0,0)`). Single-pass over the slice.
// Useful for "first occurrence" / "leftmost-deadline-wins" reductions.
fun EarliestOf(times []Time) Time {
    var n int = len(times)
    if n == 0 { ret new Time {ns: 0} }
    var best Time = times[0]
    for i := 1; i < n; i++ {
        if times[i].ns < best.ns { best = times[i] }
    }
    ret best
}

// LatestOf returns the latest Time in `times`. Empty input returns
// the zero Time. Counterpart to EarliestOf. Useful for "most recent
// event" / "last-updated wins" reductions over a list of timestamps.
fun LatestOf(times []Time) Time {
    var n int = len(times)
    if n == 0 { ret new Time {ns: 0} }
    var best Time = times[0]
    for i := 1; i < n; i++ {
        if times[i].ns > best.ns { best = times[i] }
    }
    ret best
}

// floorDiv is integer division rounding toward negative infinity (not
// toward zero). Needed for the day algorithm on negative epochs.
fun floorDiv(a int, b int) int {
    var q int = a / b
    var r int = a - q * b
    if r != 0 {
        if r < 0 {
            if b > 0 { q = q - 1 }
        } else {
            if b < 0 { q = q - 1 }
        }
    }
    ret q
}

// daysSinceEpoch returns the number of whole days from Jan 1 1970.
// Negative for pre-epoch instants.
fun (t Time) daysSinceEpoch() int {
    ret floorDiv(t.ns, 86400000000000)
}

// civilFromDays implements Howard Hinnant's algorithm: given a count
// of days from 1970-01-01, return (year, month, day) in the proleptic
// Gregorian calendar (UTC). month is 1..12, day is 1..31.
fun civilFromDays(z int) (int, int, int) {
    z = z + 719468
    var era int = 0
    if z >= 0 {
        era = z / 146097
    } else {
        era = (z - 146096) / 146097
    }
    var doe int = z - era * 146097                          // [0, 146096]
    var yoe int = (doe - doe/1460 + doe/36524 - doe/146096) / 365  // [0, 399]
    var y int = yoe + era * 400
    var doy int = doe - (365*yoe + yoe/4 - yoe/100)         // [0, 365]
    var mp int = (5*doy + 2) / 153                          // [0, 11]
    var d int = doy - (153*mp + 2)/5 + 1                    // [1, 31]
    var m int = mp + 3
    if mp >= 10 { m = mp - 9 }
    if m <= 2 { y = y + 1 }
    ret y, m, d
}

fun (t Time) ymd() (int, int, int) {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = civilFromDays(t.daysSinceEpoch())
    ret y, m, d
}

fun (t Time) Year() int {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.ymd()
    if d < 0 { ret 0 }                                      // dead use to satisfy checker
    if m < 0 { ret 0 }
    ret y
}

fun (t Time) Month() int {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.ymd()
    if y < 0 { ret 0 }
    if d < 0 { ret 0 }
    ret m
}

fun (t Time) Day() int {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.ymd()
    if y < 0 { ret 0 }
    if m < 0 { ret 0 }
    ret d
}

// secondsOfDay returns seconds since 00:00 of the day t falls in.
// Always in [0, 86399].
fun (t Time) secondsOfDay() int {
    var sec int = floorDiv(t.ns, 1000000000)
    var dayStart int = floorDiv(sec, 86400) * 86400
    ret sec - dayStart
}

// YMD returns the year, month, day of t as a single multi-return.
// Public counterpart to the existing private ymd() helper. Useful
// when callers need all three calendar components at once.
fun (t Time) YMD() (int, int, int) {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.ymd()
    ret y, m, d
}

// Datetime returns (year, month, day, hour, minute, second) of t
// as a single multi-return. Saves six accessor calls when all six
// components are needed (e.g. timestamp formatting).
fun (t Time) Datetime() (int, int, int, int, int, int) {
    var y int = 0
    var mo int = 0
    var d int = 0
    y, mo, d = t.ymd()
    var sod int = t.secondsOfDay()
    var h int = sod / 3600
    var mi int = (sod / 60) % 60
    var s int = sod % 60
    ret y, mo, d, h, mi, s
}

// HMS returns the hour, minute, second of t as a single multi-
// return. Convenience over three separate accessor calls when all
// three are needed (e.g. log timestamps).
fun (t Time) HMS() (int, int, int) {
    var sod int = t.secondsOfDay()
    var h int = sod / 3600
    var m int = (sod / 60) % 60
    var s int = sod % 60
    ret h, m, s
}

fun (t Time) Hour() int   { ret t.secondsOfDay() / 3600 }
fun (t Time) Minute() int { ret (t.secondsOfDay() / 60) % 60 }
fun (t Time) Second() int { ret t.secondsOfDay() % 60 }

// IsAM reports whether t falls in the morning half of the day —
// hour in [0, 12). Equivalent to `Meridiem() == "AM"` but avoids
// string allocation.
fun (t Time) IsAM() bool {
    if t.Hour() < 12 { ret true }
    ret false
}

// IsPM reports whether t falls in the afternoon half of the day —
// hour in [12, 24). Counterpart to IsAM.
fun (t Time) IsPM() bool {
    if t.Hour() >= 12 { ret true }
    ret false
}

// Hour12 returns the hour in 12-hour-clock format (1..12). Midnight
// 00:00 → 12; 13:00 → 1. Useful for human-readable time display
// where the meridiem suffix is rendered separately.
fun (t Time) Hour12() int {
    var h int = t.Hour() % 12
    if h == 0 { ret 12 }
    ret h
}

// Meridiem returns "AM" or "PM" based on whether t's hour is in
// the [0, 11] or [12, 23] half of the day. Useful for 12-hour
// clock formatters paired with Hour12.
fun (t Time) Meridiem() string {
    if t.Hour() < 12 { ret "AM" }
    ret "PM"
}

// pad2 returns a 2-character zero-padded decimal string for 0..99.
fun pad2(n int) string {
    if n < 10 {
        ret "0" + strconv.Itoa(n)
    }
    ret strconv.Itoa(n)
}

// pad4 returns a 4-character zero-padded decimal string for 0..9999.
fun pad4(n int) string {
    var s string = strconv.Itoa(n)
    if len(s) >= 4 { ret s }
    var pad string = ""
    for i:=len(s); i < 4; i++ { pad = pad + "0" }
    ret pad + s
}

// daysFromCivil is the inverse of civilFromDays — given a (y, m, d) in
// the proleptic Gregorian calendar, returns the count of days from
// 1970-01-01 (negative for pre-epoch dates). Howard Hinnant's algorithm.
fun daysFromCivil(y int, m int, d int) int {
    var yy int = y
    if m <= 2 { yy = yy - 1 }
    var era int = 0
    if yy >= 0 {
        era = yy / 400
    } else {
        era = (yy - 399) / 400
    }
    var yoe int = yy - era * 400
    var mp int = m - 3
    if m <= 2 { mp = m + 9 }
    var doy int = (153 * mp + 2) / 5 + d - 1
    var doe int = yoe * 365 + yoe / 4 - yoe / 100 + doy
    ret era * 146097 + doe - 719468
}

// parseDigits parses width consecutive ASCII digits starting at offset
// off in s. Returns (value, ok). Fails fast on any non-digit byte.
fun parseDigits(s string, off int, width int) (int, bool) {
    if off + width > len(s) { ret 0, false }
    var v int = 0
    for i:=0; i < width; i++ {
        var b int = s[off + i] & 255
        if b < 48 { ret 0, false }
        if b > 57 { ret 0, false }
        v = v * 10 + (b - 48)
    }
    ret v, true
}

// ParseRFC3339 parses the fixed `YYYY-MM-DDTHH:MM:SSZ` form (20 chars,
// UTC only — fractional seconds and explicit offsets are not yet
// supported). Round-trips with Format. Validates separator bytes and
// numeric ranges (month 1..12, day 1..31, hour 0..23, minute/sec 0..59).
fun ParseRFC3339(s string) (Time, error) {
    var zero Time = new Time {ns: 0}
    if len(s) != 20 {
        ret zero, errors.New("time: RFC3339 needs 20 chars `YYYY-MM-DDTHH:MM:SSZ`")
    }
    // 45='-', 84='T', 58=':', 90='Z'
    if s[4]  != 45 { ret zero, errors.New("time: RFC3339 missing '-' at offset 4") }
    if s[7]  != 45 { ret zero, errors.New("time: RFC3339 missing '-' at offset 7") }
    if s[10] != 84 { ret zero, errors.New("time: RFC3339 missing 'T' at offset 10") }
    if s[13] != 58 { ret zero, errors.New("time: RFC3339 missing ':' at offset 13") }
    if s[16] != 58 { ret zero, errors.New("time: RFC3339 missing ':' at offset 16") }
    if s[19] != 90 { ret zero, errors.New("time: RFC3339 missing 'Z' at offset 19") }

    var y int = 0
    var mo int = 0
    var d int = 0
    var h int = 0
    var mi int = 0
    var sec int = 0
    var ok bool = true

    y, ok = parseDigits(s, 0, 4)
    if !ok { ret zero, errors.New("time: RFC3339 bad year digits") }
    mo, ok = parseDigits(s, 5, 2)
    if !ok { ret zero, errors.New("time: RFC3339 bad month digits") }
    d, ok = parseDigits(s, 8, 2)
    if !ok { ret zero, errors.New("time: RFC3339 bad day digits") }
    h, ok = parseDigits(s, 11, 2)
    if !ok { ret zero, errors.New("time: RFC3339 bad hour digits") }
    mi, ok = parseDigits(s, 14, 2)
    if !ok { ret zero, errors.New("time: RFC3339 bad minute digits") }
    sec, ok = parseDigits(s, 17, 2)
    if !ok { ret zero, errors.New("time: RFC3339 bad second digits") }

    if mo < 1  { ret zero, errors.New("time: month < 1") }
    if mo > 12 { ret zero, errors.New("time: month > 12") }
    if d  < 1  { ret zero, errors.New("time: day < 1") }
    if d  > 31 { ret zero, errors.New("time: day > 31") }
    if h  > 23 { ret zero, errors.New("time: hour > 23") }
    if mi > 59 { ret zero, errors.New("time: minute > 59") }
    if sec > 60 { ret zero, errors.New("time: second > 60") }   // 60 = leap sec

    var days int = daysFromCivil(y, mo, d)
    var totalSec int = days * 86400 + h * 3600 + mi * 60 + sec
    var t Time = new Time {ns: totalSec * 1000000000}
    ret t, nil
}

// ParseDate parses a date-only string `YYYY-MM-DD` (10 chars) and
// returns a Time at midnight UTC on that civil date. Validates
// separator bytes and numeric ranges (month 1..12, day 1..31).
// Useful for parsing calendar dates from config files / CLI args /
// CSV columns without needing to construct a full RFC3339 string.
// Pairs with `t.DateString()` for round-trip.
fun ParseDate(s string) (Time, error) {
    var zero Time = new Time {ns: 0}
    if len(s) != 10 {
        ret zero, errors.New("time: date needs 10 chars `YYYY-MM-DD`")
    }
    if s[4] != 45 { ret zero, errors.New("time: date missing '-' at offset 4") }
    if s[7] != 45 { ret zero, errors.New("time: date missing '-' at offset 7") }

    var y int = 0
    var mo int = 0
    var d int = 0
    var ok bool = true
    y, ok = parseDigits(s, 0, 4)
    if !ok { ret zero, errors.New("time: date bad year digits") }
    mo, ok = parseDigits(s, 5, 2)
    if !ok { ret zero, errors.New("time: date bad month digits") }
    d, ok = parseDigits(s, 8, 2)
    if !ok { ret zero, errors.New("time: date bad day digits") }

    if mo < 1  { ret zero, errors.New("time: month < 1") }
    if mo > 12 { ret zero, errors.New("time: month > 12") }
    if d  < 1  { ret zero, errors.New("time: day < 1") }
    if d  > 31 { ret zero, errors.New("time: day > 31") }

    var days int = daysFromCivil(y, mo, d)
    var t Time = new Time {ns: days * 86400 * 1000000000}
    ret t, nil
}

// Format produces an RFC3339-style timestamp: "YYYY-MM-DDTHH:MM:SSZ".
// (Layout strings are not yet parsed — fixed format in v1.)
// O(n) via bytes.Builder (Pass 108).
fun (t Time) Format() string {
    var y int = t.Year()
    var mo int = t.Month()
    var d int = t.Day()
    var h int = t.Hour()
    var mi int = t.Minute()
    var s int = t.Second()
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(pad4(y))
    b.WriteByte(45)   // '-'
    b.WriteString(pad2(mo))
    b.WriteByte(45)
    b.WriteString(pad2(d))
    b.WriteByte(84)   // 'T'
    b.WriteString(pad2(h))
    b.WriteByte(58)   // ':'
    b.WriteString(pad2(mi))
    b.WriteByte(58)
    b.WriteString(pad2(s))
    b.WriteByte(90)   // 'Z'
    ret b.String()
}

// HumanDate returns a long-form English calendar date —
// "Weekday, Month Day, Year" (e.g. "Saturday, June 15, 2024").
// Uses WeekdayName + MonthName + the Itoa'd day / year.
fun (t Time) HumanDate() string {
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(t.WeekdayName())
    b.WriteByte(44)   // ','
    b.WriteByte(32)   // ' '
    b.WriteString(MonthName(t.Month()))
    b.WriteByte(32)
    b.WriteString(strconv.Itoa(t.Day()))
    b.WriteByte(44)
    b.WriteByte(32)
    b.WriteString(strconv.Itoa(t.Year()))
    ret b.String()
}

// ShortDate returns a compact English calendar date — "Mon Day,
// Year" (e.g. "Jun 15, 2024"). Useful for tight UI rows that need
// human-readable rather than ISO format.
fun (t Time) ShortDate() string {
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(t.MonthShortName())
    b.WriteByte(32)
    b.WriteString(strconv.Itoa(t.Day()))
    b.WriteByte(44)
    b.WriteByte(32)
    b.WriteString(strconv.Itoa(t.Year()))
    ret b.String()
}

// DateTimeString returns "YYYY-MM-DD HH:MM:SS" — Date and Time
// joined by a single space (RFC-friendly but more readable than
// the `T...Z` Format() output for log lines).
fun (t Time) DateTimeString() string {
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(t.DateString())
    b.WriteByte(32)   // ' '
    b.WriteString(t.TimeString())
    ret b.String()
}

// IsoCompact returns the compact ISO 8601 basic-format timestamp
// "YYYYMMDDTHHMMSSZ" — no separators, suitable for filenames and
// other paths where ':' is awkward (e.g. backup-20240615T153042Z.tar).
fun (t Time) IsoCompact() string {
    var y int = t.Year()
    var mo int = t.Month()
    var d int = t.Day()
    var h int = t.Hour()
    var mi int = t.Minute()
    var s int = t.Second()
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(pad4(y))
    b.WriteString(pad2(mo))
    b.WriteString(pad2(d))
    b.WriteByte(84)   // 'T'
    b.WriteString(pad2(h))
    b.WriteString(pad2(mi))
    b.WriteString(pad2(s))
    b.WriteByte(90)   // 'Z'
    ret b.String()
}

// TimeString returns the 24-hour "HH:MM:SS" portion of t — every
// field zero-padded to 2 digits. Counterpart to DateString.
// Combine for a non-RFC "YYYY-MM-DD HH:MM:SS" by sandwiching a
// space (or use Format() for RFC3339).
fun (t Time) TimeString() string {
    var h int = t.Hour()
    var mi int = t.Minute()
    var s int = t.Second()
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(pad2(h))
    b.WriteByte(58)   // ':'
    b.WriteString(pad2(mi))
    b.WriteByte(58)
    b.WriteString(pad2(s))
    ret b.String()
}

// TimeStringShort returns the 24-hour "HH:MM" portion of t —
// minute-precision time-of-day for compact UI presentation.
fun (t Time) TimeStringShort() string {
    var h int = t.Hour()
    var mi int = t.Minute()
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(pad2(h))
    b.WriteByte(58)
    b.WriteString(pad2(mi))
    ret b.String()
}

// Format12Hour produces an "h:mm AM/PM" timestamp for t — 12-hour
// clock with non-padded leading hour and zero-padded minute. Useful
// for human-readable UI output ("3:05 PM" rather than "15:05").
fun (t Time) Format12Hour() string {
    var h int = t.Hour12()
    var mi int = t.Minute()
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(strconv.Itoa(h))
    b.WriteByte(58)   // ':'
    b.WriteString(pad2(mi))
    b.WriteByte(32)   // ' '
    b.WriteString(t.Meridiem())
    ret b.String()
}

// Format12HourFull produces an "h:mm:ss AM/PM" timestamp for t —
// 12-hour clock with seconds included. Companion to Format12Hour.
fun (t Time) Format12HourFull() string {
    var h int = t.Hour12()
    var mi int = t.Minute()
    var s int = t.Second()
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(strconv.Itoa(h))
    b.WriteByte(58)
    b.WriteString(pad2(mi))
    b.WriteByte(58)
    b.WriteString(pad2(s))
    b.WriteByte(32)
    b.WriteString(t.Meridiem())
    ret b.String()
}

// DateString returns just the YYYY-MM-DD portion of t (the
// Format() result without the time-of-day suffix).
fun (t Time) DateString() string {
    var y int = t.Year()
    var mo int = t.Month()
    var d int = t.Day()
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(pad4(y))
    b.WriteByte(45)
    b.WriteString(pad2(mo))
    b.WriteByte(45)
    b.WriteString(pad2(d))
    ret b.String()
}

// NowString returns the current wall-clock time formatted as RFC3339
// — convenience for log timestamps. Equivalent to
// FromNano(Now()).Format().
fun NowString() string {
    var t Time = FromNano(Now())
    ret t.Format()
}

// NowDate returns the current wall-clock date as "YYYY-MM-DD".
fun NowDate() string {
    var t Time = FromNano(Now())
    ret t.DateString()
}

// UTCNow returns the current wall-clock time as a Time value (UTC).
// Convenience over `FromNano(Now())` — saves the two-call dance
// when callers immediately want a Time, not the bare-ns int.
// Equivalent to Go's `time.Now()` (volt's `Now()` already returns
// ns since epoch, hence the naming asymmetry).
fun UTCNow() Time {
    ret FromNano(Now())
}

// Today returns a Time at 00:00:00.000000000 UTC on the current
// civil date — `Now()` truncated down to the day. Useful as a
// canonical "start of today" anchor for daily counters, log-bucket
// keys, and TTL math that should snap to a calendar boundary
// rather than a rolling 24-hour window. Equivalent to
// `FromNano(Now()).StartOfDay()` but more direct at call sites.
fun Today() Time {
    var t Time = FromNano(Now())
    ret t.StartOfDay()
}

// Yesterday returns a Time at midnight UTC on the civil day before
// the current one. Shorthand for `Today().Yesterday()`. Useful for
// "previous day's bucket" queries — daily reports, change diffs,
// rate-limit-window rollovers.
fun Yesterday() Time {
    var t Time = Today()
    ret t.Yesterday()
}

// Tomorrow returns a Time at midnight UTC on the civil day after
// the current one. Shorthand for `Today().Tomorrow()`. Useful for
// scheduling deadlines, expiration anchors, and "next day's bucket"
// pre-allocation.
fun Tomorrow() Time {
    var t Time = Today()
    ret t.Tomorrow()
}

// FormatDuration renders a nanosecond duration as a human-readable
// string. Negative durations are prefixed with `-`. Picks the
// coarsest unit that holds the integer magnitude and emits in
// `<n><unit>` form: `ns`, `us`, `ms`, `s`, or for ≥ 1 minute
// `Xm Ys`, for ≥ 1 hour `Xh Ym`. Truncates rather than rounds.
//
// Less-flexible than Go's time.Duration.String() but adequate for
// log/debug output. Zero returns `0s`.
// ParseDuration parses `<int><unit>` and returns nanoseconds.
// Supported units (suffix order matters — 2-char first):
//   `ns` → 1ns, `us` → 1000ns, `ms` → 1000000ns,
//   `s`  → 1000000000ns, `m` → 60s, `h` → 3600s.
// Leading `-` is accepted for negative durations. Whitespace, decimal
// points, and the multi-part `Xh Ym` form (output of FormatDuration
// for ≥ 1h) are NOT accepted in v1 — single magnitude + unit only.
// Empty / no-unit / no-digit inputs return an error. Inverse of
// FormatDuration for single-unit outputs.
fun ParseDuration(s string) (int, error) {
    var n int = len(s)
    if n == 0 { ret 0, errors.New("time: empty duration") }
    var i int = 0
    var neg bool = false
    if s[0] == 45 {
        neg = true
        i = 1
    }
    if i >= n { ret 0, errors.New("time: no digits in duration") }
    // Parse digits.
    var v int = 0
    var hasDigit bool = false
    for i < n {
        var c byte = s[i]
        if c < 48 { break }
        if c > 57 { break }
        v = v * 10 + (c - 48)
        hasDigit = true
        i = i + 1
    }
    if !hasDigit { ret 0, errors.New("time: no digits in duration") }
    if i >= n { ret 0, errors.New("time: missing unit in duration") }
    // Determine unit (2-char first).
    var rem int = n - i
    var mul int = 0
    if rem >= 2 {
        if s[i] == 110 {
            if s[i+1] == 115 {                  // "ns"
                if rem == 2 { mul = 1 }
            }
        }
        if s[i] == 117 {
            if s[i+1] == 115 {                  // "us"
                if rem == 2 { mul = 1000 }
            }
        }
        if s[i] == 109 {
            if s[i+1] == 115 {                  // "ms"
                if rem == 2 { mul = 1000000 }
            }
        }
    }
    if mul == 0 {
        if rem == 1 {
            if s[i] == 115 { mul = 1000000000 }              // 's'
            if s[i] == 109 { mul = 60 * 1000000000 }         // 'm'
            if s[i] == 104 { mul = 3600 * 1000000000 }       // 'h'
        }
    }
    if mul == 0 { ret 0, errors.New("time: unknown duration unit") }
    var ns int = v * mul
    if neg { ns = -ns }
    ret ns, nil
}

fun FormatDuration(ns int) string {
    if ns == 0 { ret "0s" }
    var neg bool = false
    if ns < 0 {
        neg = true
        ns = -ns
    }
    var b *bytes.Builder = bytes.NewBuilder()
    if neg { b.WriteByte(45) }   // '-'
    // Hours.
    if ns >= 3600000000000 {
        var h int = ns / 3600000000000
        var rem int = ns - h * 3600000000000
        var m int = rem / 60000000000
        b.WriteInt(h)
        b.WriteByte(104)   // 'h'
        if m > 0 {
            b.WriteByte(32)
            b.WriteInt(m)
            b.WriteByte(109)
        }
        ret b.String()
    }
    if ns >= 60000000000 {
        var m int = ns / 60000000000
        var rem int = ns - m * 60000000000
        var s int = rem / 1000000000
        b.WriteInt(m)
        b.WriteByte(109)   // 'm'
        if s > 0 {
            b.WriteByte(32)
            b.WriteInt(s)
            b.WriteByte(115)
        }
        ret b.String()
    }
    if ns >= 1000000000 {
        b.WriteInt(ns / 1000000000)
        b.WriteByte(115)   // 's'
        ret b.String()
    }
    if ns >= 1000000 {
        b.WriteInt(ns / 1000000)
        b.WriteString("ms")
        ret b.String()
    }
    if ns >= 1000 {
        b.WriteInt(ns / 1000)
        b.WriteString("us")
        ret b.String()
    }
    b.WriteInt(ns)
    b.WriteString("ns")
    ret b.String()
}

// StartOfDay returns t rounded down to UTC midnight (00:00:00.000).
// Time-of-day is dropped; the calendar date is preserved. Useful for
// "today's events" range queries.
fun StartOfDay(t Time) Time {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.YMD()
    ret Date(y, m, d, 0, 0, 0, 0)
}

// EndOfDay returns t rounded up to the last representable nanosecond
// of the same UTC day (23:59:59.999999999). Useful as the upper
// bound for "today's events" range queries.
fun EndOfDay(t Time) Time {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.YMD()
    ret Date(y, m, d, 23, 59, 59, 999999999)
}

// StartOfMonth returns t rounded down to the first instant (UTC
// midnight) of the same calendar month. Useful for monthly
// aggregation windows ("transactions this month").
fun StartOfMonth(t Time) Time {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.YMD()
    if d == 0 { d = d }   // unused-var dodge — drop d
    ret Date(y, m, 1, 0, 0, 0, 0)
}

// EndOfMonth returns t rounded up to the last representable
// nanosecond of the same calendar month. Uses DaysInMonth to handle
// 28/29/30/31-day months correctly.
fun EndOfMonth(t Time) Time {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.YMD()
    if d == 0 { d = d }
    var last int = DaysInMonth(y, m)
    ret Date(y, m, last, 23, 59, 59, 999999999)
}

// DaysLeftInYear returns the number of days remaining in the
// calendar year from t (inclusive of t's day → 0 on Dec 31).
// Companion to DayOfYear: `DayOfYear(t) + DaysLeftInYear(t) ==
// DaysInYear(year)`. Useful for progress bars, fiscal-year reporting.
fun DaysLeftInYear(t Time) int {
    var y int = t.Year()
    ret DaysInYear(y) - DayOfYear(t)
}

// DaysLeftInMonth returns the number of days remaining in the
// calendar month from t (inclusive of t's day → 0 on the last day).
// Cross-property: `t.Day() + DaysLeftInMonth(t) == DaysInMonth(y,m)`.
fun DaysLeftInMonth(t Time) int {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.YMD()
    ret DaysInMonth(y, m) - d
}

// IsBirthday reports whether the month-and-day of ref match those
// of birth. Year is ignored. Feb 29 birthdays only match on Feb 29
// in leap years — callers wanting "promote to Mar 1 in non-leap"
// behavior should adjust before calling.
fun IsBirthday(birth Time, ref Time) bool {
    var bm int = birth.Month()
    var bd int = birth.Day()
    var rm int = ref.Month()
    var rd int = ref.Day()
    if bm != rm { ret false }
    if bd != rd { ret false }
    ret true
}

// DaysUntilBirthday returns the number of full days from ref to the
// NEXT occurrence of birth's month+day (>= 0). If ref is exactly on
// the birthday, returns 0. Feb 29 birthdays in a non-leap target year
// roll to Mar 1 (standard convention).
fun DaysUntilBirthday(birth Time, ref Time) int {
    var bm int = birth.Month()
    var bd int = birth.Day()
    var ry int = 0
    var rm int = 0
    var rd int = 0
    ry, rm, rd = ref.YMD()
    if rd == 0 { rd = rd }
    // Try birthday in the current ref year.
    var candidate Time = makeBirthdayInYear(ry, bm, bd)
    var refMidnight Time = StartOfDay(ref)
    var diff int = DiffDays(candidate, refMidnight)
    if diff >= 0 { ret diff }
    // Otherwise roll to next year.
    var nextYr Time = makeBirthdayInYear(ry + 1, bm, bd)
    if rm == 0 { rm = rm }   // silence the unused-var checker
    ret DiffDays(nextYr, refMidnight)
}

// makeBirthdayInYear constructs a midnight Time at the given
// year/month/day, rolling Feb 29 → Mar 1 in non-leap years.
fun makeBirthdayInYear(year int, month int, day int) Time {
    if month == 2 {
        if day == 29 {
            if !IsLeapYear(year) {
                ret Date(year, 3, 1, 0, 0, 0, 0)
            }
        }
    }
    ret Date(year, month, day, 0, 0, 0, 0)
}

// AgeInYears returns the integer age in years given a birth time
// and a reference time. Subtracts birth year from ref year, then
// adjusts by 1 if the birthday hasn't yet occurred in the ref
// year. Negative birth-after-ref returns 0 (not -ve).
// Useful for "happy birthday" check, age-gated content, year-based
// elapsed calculations.
fun AgeInYears(birth Time, ref Time) int {
    var by int = 0
    var bm int = 0
    var bd int = 0
    by, bm, bd = birth.YMD()
    var ry int = 0
    var rm int = 0
    var rd int = 0
    ry, rm, rd = ref.YMD()
    if ry < by { ret 0 }
    var age int = ry - by
    if rm < bm {
        age = age - 1
    } else {
        if rm == bm {
            if rd < bd { age = age - 1 }
        }
    }
    if age < 0 { ret 0 }
    ret age
}

// DayOfYear returns the 1-indexed day-of-year for t (1 on Jan 1,
// up to 365 in a non-leap year or 366 in a leap year). Useful for
// astronomy / agriculture / business-cycle math where the day
// number matters more than the month.
fun DayOfYear(t Time) int {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.YMD()
    var total int = d
    for i := 1; i < m; i++ {
        total = total + DaysInMonth(y, i)
    }
    ret total
}

// WeekOfYear returns the 1-based week number of t within its year
// using a simple "calendar week" definition: week 1 starts on Jan 1
// and weeks roll over every 7 days. So Jan 1-7 = week 1, Jan 8-14 =
// week 2, etc., regardless of which weekday Jan 1 lands on. Common
// alternatives (ISO-8601 weeks-starting-Monday) need the year's
// first-Monday alignment which is more complex; this calendar-week
// version is what most reporting + UI bucketing wants. Result is
// 1..53.
fun WeekOfYear(t Time) int {
    var doy int = DayOfYear(t)
    ret (doy - 1) / 7 + 1
}

// QuarterOf returns the calendar quarter (1..4) that contains t.
// Q1 = Jan-Mar, Q2 = Apr-Jun, Q3 = Jul-Sep, Q4 = Oct-Dec. Useful
// for quarterly reporting labels and bucketing.
fun QuarterOf(t Time) int {
    var m int = t.Month()
    ret (m - 1) / 3 + 1
}

// StartOfQuarter returns t rounded down to UTC midnight on the
// first day of the calendar quarter that contains t (Jan 1, Apr 1,
// Jul 1, or Oct 1). Useful for quarterly aggregation windows.
fun StartOfQuarter(t Time) Time {
    var y int = 0
    var mo int = 0
    var d int = 0
    y, mo, d = t.YMD()
    if d == 0 { d = d }
    var qMonth int = ((mo - 1) / 3) * 3 + 1
    ret Date(y, qMonth, 1, 0, 0, 0, 0)
}

// EndOfQuarter returns t rounded up to the last representable
// nanosecond of the last day of the calendar quarter that contains
// t (Mar 31, Jun 30, Sep 30, or Dec 31).
fun EndOfQuarter(t Time) Time {
    var y int = 0
    var mo int = 0
    var d int = 0
    y, mo, d = t.YMD()
    if d == 0 { d = d }
    var qLastMonth int = ((mo - 1) / 3) * 3 + 3
    var last int = DaysInMonth(y, qLastMonth)
    ret Date(y, qLastMonth, last, 23, 59, 59, 999999999)
}

// StartOfWeek returns t rounded down to the start of its ISO week
// (Monday at UTC midnight). Sunday is treated as the last day of the
// previous week. Time-of-day is dropped. Useful for weekly bucket
// aggregation ("transactions this week").
fun StartOfWeek(t Time) Time {
    var w int = t.Weekday()   // Sunday = 0, Saturday = 6
    var back int = w - 1
    if back < 0 { back = 6 }   // Sunday → 6 days back to previous Monday
    var anchor Time = AddDays(t, -back)
    ret StartOfDay(anchor)
}

// EndOfWeek returns t rounded up to the last representable
// nanosecond of its ISO week (Sunday at 23:59:59.999999999).
// Companion to StartOfWeek.
fun EndOfWeek(t Time) Time {
    var w int = t.Weekday()
    var fwd int = 7 - w   // Sunday(0) → 7 days fwd; Monday(1) → 6 fwd; Saturday(6) → 1 fwd
    if w == 0 { fwd = 0 }
    var anchor Time = AddDays(t, fwd)
    ret EndOfDay(anchor)
}

// StartOfYear returns t rounded down to the first instant (UTC
// midnight, January 1) of the same calendar year.
fun StartOfYear(t Time) Time {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.YMD()
    if m == 0 { m = m }
    if d == 0 { d = d }
    ret Date(y, 1, 1, 0, 0, 0, 0)
}

// EndOfYear returns t rounded up to the last representable
// nanosecond of December 31 of the same calendar year.
fun EndOfYear(t Time) Time {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.YMD()
    if m == 0 { m = m }
    if d == 0 { d = d }
    ret Date(y, 12, 31, 23, 59, 59, 999999999)
}

// StartOfMinute returns t rounded down to the start of its current
// minute (ss:ns all zero). Useful for per-minute aggregation buckets.
fun StartOfMinute(t Time) Time {
    var y int = 0
    var mo int = 0
    var d int = 0
    y, mo, d = t.YMD()
    ret Date(y, mo, d, t.Hour(), t.Minute(), 0, 0)
}

// EndOfMinute returns t rounded up to the last representable
// nanosecond of its current minute (mm:59.999999999).
fun EndOfMinute(t Time) Time {
    var y int = 0
    var mo int = 0
    var d int = 0
    y, mo, d = t.YMD()
    ret Date(y, mo, d, t.Hour(), t.Minute(), 59, 999999999)
}

// StartOfHour returns t rounded down to the start of its current
// hour (mm:ss:ns all zero). Useful for hourly bucket aggregation.
fun StartOfHour(t Time) Time {
    var y int = 0
    var mo int = 0
    var d int = 0
    y, mo, d = t.YMD()
    ret Date(y, mo, d, t.Hour(), 0, 0, 0)
}

// EndOfHour returns t rounded up to the last representable
// nanosecond of its current hour (hh:59:59.999999999).
fun EndOfHour(t Time) Time {
    var y int = 0
    var mo int = 0
    var d int = 0
    y, mo, d = t.YMD()
    ret Date(y, mo, d, t.Hour(), 59, 59, 999999999)
}

// AddBusinessDays returns t shifted by n business days (Mon-Fri),
// skipping weekend days. n > 0 advances forward; n < 0 rolls back;
// n == 0 returns t unchanged. If t itself is a weekend, advancing
// by n=1 lands on Monday + 0 (i.e. the next weekday). Time-of-day
// preserved. Useful for SLA-deadline calculation, "ship by N
// business days" promises.
fun AddBusinessDays(t Time, n int) Time {
    if n == 0 { ret t }
    var d Time = t
    if n > 0 {
        for i := 0; i < n; i++ {
            d = NextWeekday(d)
        }
        ret d
    }
    var k int = -n
    for i := 0; i < k; i++ {
        d = PrevWeekday(d)
    }
    ret d
}

// BusinessDaysBetween returns the number of full business days
// (Mon-Fri) STRICTLY between a (exclusive) and b (inclusive of any
// weekday). Returns 0 if a == b, positive if b > a, negative
// (mirrored) if b < a. Weekend days never count. Useful for SLA
// elapsed-time queries, deadline-tracker computations.
fun BusinessDaysBetween(a Time, b Time) int {
    var aNs int = a.ns
    var bNs int = b.ns
    if aNs == bNs { ret 0 }
    var forward bool = bNs > aNs
    var loNs int = aNs
    var hiNs int = bNs
    if !forward {
        loNs = bNs
        hiNs = aNs
    }
    var count int = 0
    var d Time = NextWeekday(FromNano(loNs))
    for d.ns <= hiNs {
        count = count + 1
        d = NextWeekday(d)
    }
    if forward { ret count }
    ret -count
}

// NextWeekday returns the next weekday (Mon-Fri) STRICTLY AFTER t.
// If t is itself a Thu, NextWeekday returns Fri. If t is a Fri,
// returns the following Mon. If t is a weekend day, returns the
// next Monday. Time-of-day is preserved. Useful for "next
// business day delivery" / "schedule for next workday" logic.
fun NextWeekday(t Time) Time {
    var d Time = AddDays(t, 1)
    for IsWeekend(d) {
        d = AddDays(d, 1)
    }
    ret d
}

// PrevWeekday returns the previous weekday STRICTLY BEFORE t. If t
// is itself a Mon, returns the prior Fri. If t is a weekend day,
// returns the most-recent Fri. Time-of-day is preserved.
fun PrevWeekday(t Time) Time {
    var d Time = AddDays(t, -1)
    for IsWeekend(d) {
        d = AddDays(d, -1)
    }
    ret d
}

// IsWeekend reports whether t falls on a Saturday or Sunday in UTC.
// Uses the convention where Weekday()==0 is Sunday, 6 is Saturday.
// Useful for "skip weekend deliveries", "business-day only" guards.
fun IsWeekend(t Time) bool {
    var w int = t.Weekday()
    if w == 0 { ret true }
    if w == 6 { ret true }
    ret false
}

// IsWeekday reports whether t falls on a Monday through Friday in
// UTC. Companion to IsWeekend (always exclusive). Useful for
// "next business day" logic.
fun IsWeekday(t Time) bool {
    var w int = t.Weekday()
    if w == 0 { ret false }
    if w == 6 { ret false }
    ret true
}

// IsSameDay reports whether a and b fall on the same UTC calendar
// day (year, month, day all match). Time-of-day is ignored. Useful
// for "is this from today's batch?", "did these events span midnight?"
// style checks.
fun IsSameDay(a Time, b Time) bool {
    var ay int = 0
    var am int = 0
    var ad int = 0
    ay, am, ad = a.YMD()
    var by int = 0
    var bm int = 0
    var bd int = 0
    by, bm, bd = b.YMD()
    if ay != by { ret false }
    if am != bm { ret false }
    if ad != bd { ret false }
    ret true
}

// IsToday reports whether t falls on today's UTC calendar day.
fun IsToday(t Time) bool {
    var now Time = FromNano(Now())
    ret IsSameDay(t, now)
}

// IsYesterday reports whether t falls on yesterday's UTC calendar
// day (current day minus 1).
fun IsYesterday(t Time) bool {
    var now Time = FromNano(Now())
    var yesterday Time = AddDays(now, -1)
    ret IsSameDay(t, yesterday)
}

// IsTomorrow reports whether t falls on tomorrow's UTC calendar
// day (current day plus 1).
fun IsTomorrow(t Time) bool {
    var now Time = FromNano(Now())
    var tomorrow Time = AddDays(now, 1)
    ret IsSameDay(t, tomorrow)
}

// HumanAgo returns a human-readable string describing how long ago
// t is relative to NOW (positive past → "X ago", future → "in X",
// exact now → "just now"). Uses HumanizeDuration for the unit
// chunking. Useful for log timestamps, "last seen" displays.
fun HumanAgo(t Time) string {
    var nowT Time = FromNano(Now())
    var delta int = nowT.Sub(t)   // > 0 if t is in the past
    if delta == 0 { ret "just now" }
    if delta > 0 {
        var b *bytes.Builder = bytes.NewBuilder()
        b.WriteString(HumanizeDuration(delta))
        b.WriteString(" ago")
        ret b.String()
    }
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString("in ")
    b.WriteString(HumanizeDuration(-delta))
    ret b.String()
}

// HumanAgoFromNanos is the offset-driven version of HumanAgo for
// callers that already hold a nanosecond delta (mono-clock
// measurements, pre-computed offsets). Negative delta = past;
// positive = future; zero = "just now".
fun HumanAgoFromNanos(delta int) string {
    if delta == 0 { ret "just now" }
    if delta < 0 {
        var b *bytes.Builder = bytes.NewBuilder()
        b.WriteString(HumanizeDuration(-delta))
        b.WriteString(" ago")
        ret b.String()
    }
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString("in ")
    b.WriteString(HumanizeDuration(delta))
    ret b.String()
}

// HumanizeDuration is a chunkier version of FormatDuration that
// renders durations in human-readable form using the largest
// fitting unit. Returns:
//   - "X days" for d >= 24h
//   - "X hours" for d >= 1h
//   - "X minutes" for d >= 1m
//   - "X seconds" otherwise (d >= 0)
// Singular form ("1 day", "1 hour", "1 minute", "1 second") drops
// the trailing 's'. Negative durations get a "-" prefix. Useful for
// UI display ("active 2 hours") where FormatDuration's terse
// "2h" output is too compact.
fun HumanizeDuration(ns int) string {
    if ns == 0 { ret "0 seconds" }
    var v int = ns
    var neg bool = false
    if v < 0 {
        neg = true
        v = -v
    }
    var b *bytes.Builder = bytes.NewBuilder()
    if neg { b.WriteByte(45) }   // '-'
    if v >= 86400000000000 {
        var d int = v / 86400000000000
        b.WriteInt(d)
        if d == 1 { b.WriteString(" day") } else { b.WriteString(" days") }
        ret b.String()
    }
    if v >= 3600000000000 {
        var h int = v / 3600000000000
        b.WriteInt(h)
        if h == 1 { b.WriteString(" hour") } else { b.WriteString(" hours") }
        ret b.String()
    }
    if v >= 60000000000 {
        var m int = v / 60000000000
        b.WriteInt(m)
        if m == 1 { b.WriteString(" minute") } else { b.WriteString(" minutes") }
        ret b.String()
    }
    var s int = v / 1000000000
    if s == 0 { s = 1 }   // sub-second non-zero rounds up to "1 second"
    b.WriteInt(s)
    if s == 1 { b.WriteString(" second") } else { b.WriteString(" seconds") }
    ret b.String()
}

// AddDate returns t with civil-calendar fields shifted by years,
// months, and days. Months past December roll over into the next
// year; negative shifts roll back. Day arithmetic is done in
// nanoseconds, so adding +N days is exactly N×86400 seconds (no
// DST in v1 since volt-time is UTC-only). Time-of-day is preserved.
fun (t Time) AddDate(years int, months int, days int) Time {
    var y int = 0
    var mo int = 0
    var d int = 0
    y, mo, d = t.ymd()
    y = y + years
    mo = mo + months
    // Normalize mo into [1, 12] with adjustment to y.
    // Use moOff = mo - 1 as 0-indexed so divmod works cleanly.
    var moOff int = mo - 1
    var moInY int = moOff / 12
    var moInM int = moOff % 12
    if moInM < 0 {
        moInM = moInM + 12
        moInY = moInY - 1
    }
    y = y + moInY
    mo = moInM + 1
    // daysFromCivil handles d overflow into following months
    // naturally (Hinnant's algorithm normalizes y/m/d).
    var civilDays int = daysFromCivil(y, mo, d) + days
    var sec int = t.secondsOfDay()
    var subSec int = t.ns % 1000000000
    if subSec < 0 {
        // For pre-epoch times, t.ns is negative; subSec must be
        // in [0, 1e9) for the reassembly. Normalize.
        subSec = subSec + 1000000000
    }
    ret new Time { ns: civilDays * 86400 * 1000000000 + sec * 1000000000 + subSec }
}

// Truncate returns t rounded down toward the nearest multiple of d
// nanoseconds. Useful for bucketing timestamps (e.g. truncate to
// the start of the hour for hourly aggregation). d ≤ 0 returns t
// unchanged. Matches Go's Time.Truncate semantics — rounds toward
// zero, not toward negative infinity.
fun (t Time) Truncate(d int) Time {
    if d <= 0 { ret t }
    var ns int = t.ns - (t.ns % d)
    ret new Time { ns: ns }
}

// RoundToSecond returns t rounded to the nearest whole second.
// Convenience over `t.Round(1_000_000_000)`. Useful when nanosecond
// precision is unwanted in logs / displays.
fun (t Time) RoundToSecond() Time {
    ret t.Round(1000000000)
}

// TruncateToSecond returns t with sub-second nanoseconds zeroed —
// floor-rounding to the most recent whole second.
fun (t Time) TruncateToSecond() Time {
    ret t.Truncate(1000000000)
}

// TruncateToMinute returns t with seconds and nanoseconds zeroed —
// rounded DOWN to the most recent whole minute. Counterpart to
// RoundToMinute (round-to-nearest). Useful for minute-aligned
// floor-bucketing in time-series aggregation.
fun (t Time) TruncateToMinute() Time {
    ret t.Truncate(60000000000)
}

// TruncateToHour returns t rounded DOWN to the most recent whole
// hour. Counterpart to RoundToHour.
fun (t Time) TruncateToHour() Time {
    ret t.Truncate(3600000000000)
}

// RoundToMinute returns t rounded to the nearest whole minute.
// Convenience over `t.Round(60 * 1_000_000_000)`. Ties (exactly 30
// seconds) round away from zero. Useful for clock-aligned event
// bucketing.
fun (t Time) RoundToMinute() Time {
    ret t.Round(60000000000)
}

// RoundToHour returns t rounded to the nearest whole hour.
// Convenience over `t.Round(3600 * 1_000_000_000)`. Useful for
// hourly metric / log aggregation.
fun (t Time) RoundToHour() Time {
    ret t.Round(3600000000000)
}

// Round returns t rounded to the nearest multiple of d nanoseconds.
// Ties (exactly half-way) round away from zero. d ≤ 0 returns t.
fun (t Time) Round(d int) Time {
    if d <= 0 { ret t }
    var rem int = t.ns % d
    var half int = d / 2
    if rem >= half {
        ret new Time { ns: t.ns + (d - rem) }
    }
    if rem <= -half {
        ret new Time { ns: t.ns - (d + rem) }
    }
    ret new Time { ns: t.ns - rem }
}

// DayOfWeekISO returns the ISO 8601 weekday number — Monday = 1
// through Sunday = 7. Maps from the existing Weekday() (Sun=0..
// Sat=6) by shifting Sun → 7. Useful when interfacing with ISO
// calendar libraries or DBs that follow the Mon-start convention.
fun (t Time) DayOfWeekISO() int {
    var w int = t.Weekday()
    if w == 0 { ret 7 }
    ret w
}

// Weekday returns the day of the week, 0 = Sunday through 6 =
// Saturday. Jan 1 1970 was a Thursday (= 4), so the day-of-week
// is `(daysSinceEpoch + 4) mod 7`, normalized to [0, 6] for
// negative day counts.
fun (t Time) Weekday() int {
    var d int = t.daysSinceEpoch() + 4
    var w int = d % 7
    if w < 0 { w = w + 7 }
    ret w
}

// WeekdayShortName returns the 3-letter English abbreviation for
// t's weekday — "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat".
// Useful for compact log lines, table headers, calendar UIs.
fun (t Time) WeekdayShortName() string {
    var w int = t.Weekday()
    if w == 0 { ret "Sun" }
    if w == 1 { ret "Mon" }
    if w == 2 { ret "Tue" }
    if w == 3 { ret "Wed" }
    if w == 4 { ret "Thu" }
    if w == 5 { ret "Fri" }
    ret "Sat"
}

// MonthShortName returns the 3-letter English abbreviation for
// t's month — "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul",
// "Aug", "Sep", "Oct", "Nov", "Dec". Useful for compact log
// formatting (e.g. syslog "Jan 23 15:04:05").
fun (t Time) MonthShortName() string {
    var m int = t.Month()
    if m == 1 { ret "Jan" }
    if m == 2 { ret "Feb" }
    if m == 3 { ret "Mar" }
    if m == 4 { ret "Apr" }
    if m == 5 { ret "May" }
    if m == 6 { ret "Jun" }
    if m == 7 { ret "Jul" }
    if m == 8 { ret "Aug" }
    if m == 9 { ret "Sep" }
    if m == 10 { ret "Oct" }
    if m == 11 { ret "Nov" }
    ret "Dec"
}

// WeekdayName returns the English name of the weekday — "Sunday"
// through "Saturday". Useful for log formatting.
fun (t Time) WeekdayName() string {
    var w int = t.Weekday()
    if w == 0 { ret "Sunday" }
    if w == 1 { ret "Monday" }
    if w == 2 { ret "Tuesday" }
    if w == 3 { ret "Wednesday" }
    if w == 4 { ret "Thursday" }
    if w == 5 { ret "Friday" }
    ret "Saturday"
}

// IsAtOrBefore reports whether t occurs at the same instant as
// u or earlier (t.ns <= u.ns). Inclusive companion to Before.
fun (t Time) IsAtOrBefore(u Time) bool {
    if t.ns <= u.ns { ret true }
    ret false
}

// IsAtOrAfter reports whether t occurs at the same instant as u
// or later (t.ns >= u.ns). Inclusive companion to After.
fun (t Time) IsAtOrAfter(u Time) bool {
    if t.ns >= u.ns { ret true }
    ret false
}

// Min returns the earlier of t and u (lower ns). Returns t when
// they're equal. Useful for clamping a candidate timestamp to a
// deadline.
fun (t Time) Min(u Time) Time {
    if u.ns < t.ns { ret u }
    ret t
}

// Max returns the later of t and u (higher ns). Returns t when
// they're equal.
fun (t Time) Max(u Time) Time {
    if u.ns > t.ns { ret u }
    ret t
}

// WithMonth returns t with only the calendar month swapped. Year,
// day, and full time-of-day preserved. Day overflow on the target
// month spills forward (e.g. Jan 31 → "Feb 31" → Mar 3 leap-year).
fun (t Time) WithMonth(mo int) Time {
    var origY int = 0
    var origMo int = 0
    var d int = 0
    origY, origMo, d = t.ymd()
    if origMo < 0 { ret t }                                  // dead use to satisfy checker
    var nano int = t.ns % 1000000000
    if nano < 0 { nano = nano + 1000000000 }
    ret Date(origY, mo, d, t.Hour(), t.Minute(), t.Second(), nano)
}

// WithDay returns t with only the day-of-month swapped. Same
// overflow-not-clamp semantics — `WithDay(31)` on a 30-day month
// resolves to the 1st of the next month.
fun (t Time) WithDay(d int) Time {
    var y int = 0
    var mo int = 0
    var origD int = 0
    y, mo, origD = t.ymd()
    if origD < 0 { ret t }                                   // dead use to satisfy checker
    var nano int = t.ns % 1000000000
    if nano < 0 { nano = nano + 1000000000 }
    ret Date(y, mo, d, t.Hour(), t.Minute(), t.Second(), nano)
}

// WithMinute returns t with only the minute swapped. Hour, second,
// and nanoseconds preserved. Companion to WithHour / WithSecond.
fun (t Time) WithMinute(m int) Time {
    var y int = 0
    var mo int = 0
    var d int = 0
    y, mo, d = t.ymd()
    var nano int = t.ns % 1000000000
    if nano < 0 { nano = nano + 1000000000 }
    ret Date(y, mo, d, t.Hour(), m, t.Second(), nano)
}

// WithSecond returns t with only the second swapped. Hour, minute,
// and nanoseconds preserved. Useful for sub-second-precision
// adjustment without manual reconstruction.
fun (t Time) WithSecond(s int) Time {
    var y int = 0
    var mo int = 0
    var d int = 0
    y, mo, d = t.ymd()
    var nano int = t.ns % 1000000000
    if nano < 0 { nano = nano + 1000000000 }
    ret Date(y, mo, d, t.Hour(), t.Minute(), s, nano)
}

// WithHour returns t with only its hour-of-day swapped; minute,
// second, and nanosecond are preserved. Useful for: "anchor at 9am
// on whatever day this is", scheduled-job time normalization.
fun (t Time) WithHour(h int) Time {
    var y int = 0
    var mo int = 0
    var d int = 0
    y, mo, d = t.ymd()
    var nano int = t.ns % 1000000000
    if nano < 0 { nano = nano + 1000000000 }
    ret Date(y, mo, d, h, t.Minute(), t.Second(), nano)
}

// WithYear returns t with only its calendar year swapped. Preserves
// month, day, and full time-of-day. Useful for: copying a recurring
// holiday / anniversary to a different year.
fun (t Time) WithYear(y int) Time {
    var origY int = 0
    var mo int = 0
    var d int = 0
    origY, mo, d = t.ymd()
    if origY < 0 { ret t }                                  // dead use to satisfy checker
    var nano int = t.ns % 1000000000
    if nano < 0 { nano = nano + 1000000000 }
    ret Date(y, mo, d, t.Hour(), t.Minute(), t.Second(), nano)
}

// WithTime returns t with its time-of-day replaced by (h, m, s).
// Nanoseconds are dropped. The calendar date is preserved. Useful
// for: "set this date to noon", "anchor at midnight" without manual
// Date() reconstruction.
fun (t Time) WithTime(h int, m int, s int) Time {
    var y int = 0
    var mo int = 0
    var d int = 0
    y, mo, d = t.ymd()
    ret Date(y, mo, d, h, m, s, 0)
}

// WithDate returns t with its calendar date replaced by (y, mo, d).
// The time-of-day is preserved (hour, minute, second, nanosecond).
// Useful for: moving an event-instant to a different day while
// keeping the same wall-clock alarm time.
fun (t Time) WithDate(y int, mo int, d int) Time {
    var h int = t.Hour()
    var mi int = t.Minute()
    var s int = t.Second()
    var nano int = t.ns % 1000000000
    if nano < 0 { nano = nano + 1000000000 }
    ret Date(y, mo, d, h, mi, s, nano)
}

// StartOfDay returns the instant 00:00:00.000000000 on the same
// civil day as t. Useful for bucketing events into day windows
// without manual midnight construction.
fun (t Time) StartOfDay() Time {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.ymd()
    ret Date(y, m, d, 0, 0, 0, 0)
}

// EndOfDay returns the last representable nanosecond of the same
// civil day as t — 23:59:59.999999999. Combine with StartOfDay
// for an inclusive day-range filter.
fun (t Time) EndOfDay() Time {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.ymd()
    ret Date(y, m, d, 23, 59, 59, 999999999)
}

// StartOfHour returns the instant at minute=0/second=0/ns=0 of the
// same calendar hour as t. Finer-grained companion to StartOfDay.
// Useful for hourly bucketing of metrics / log entries.
fun (t Time) StartOfHour() Time {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.ymd()
    ret Date(y, m, d, t.Hour(), 0, 0, 0)
}

// EndOfHour returns the last representable nanosecond of the same
// calendar hour as t — `:59:59.999999999`. Combine with StartOfHour
// for an inclusive hour-window filter.
fun (t Time) EndOfHour() Time {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.ymd()
    ret Date(y, m, d, t.Hour(), 59, 59, 999999999)
}

// StartOfMinute returns the instant at second=0/ns=0 of the same
// minute as t. Finest-grain companion in the StartOf* family before
// raw nanoseconds. Useful for per-minute log/metric bucketing.
fun (t Time) StartOfMinute() Time {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.ymd()
    ret Date(y, m, d, t.Hour(), t.Minute(), 0, 0)
}

// EndOfMinute returns the last representable nanosecond of the same
// minute as t — `:59.999999999`. Combine with StartOfMinute for an
// inclusive minute-window filter.
fun (t Time) EndOfMinute() Time {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.ymd()
    ret Date(y, m, d, t.Hour(), t.Minute(), 59, 999999999)
}

// WeekOfMonth returns the 1-based week index within t's calendar
// month — week 1 contains day 1, weeks running Sunday→Saturday.
// Returns 1..5 (or 6 for months where the last days spill into a
// 6th calendar row). Useful for calendar grid UI placement.
fun (t Time) WeekOfMonth() int {
    var d int = t.Day()
    var firstOfMonth Time = Date(t.Year(), t.Month(), 1, 0, 0, 0, 0)
    var firstWd int = firstOfMonth.Weekday()
    ret ((d + firstWd - 1) / 7) + 1
}

// Quarter returns the calendar quarter (1, 2, 3, or 4) containing
// t — Q1 = Jan-Mar, Q2 = Apr-Jun, Q3 = Jul-Sep, Q4 = Oct-Dec.
// Useful for fiscal-period reporting, quarterly aggregates.
fun (t Time) Quarter() int {
    var m int = t.Month()
    ret ((m - 1) / 3) + 1
}

// DayOfQuarter returns the 1-based day index within t's calendar
// quarter — 1 for the first day of Q1/Q2/Q3/Q4, up to 92 for the
// last day of a 31+30+31-day quarter. Useful for quarterly progress
// bars, "X% of the way through this quarter" UI.
fun (t Time) DayOfQuarter() int {
    var qStart Time = t.StartOfQuarter()
    ret t.DaysBetween(qStart) + 1
}

// StartOfQuarter returns 00:00:00 on the 1st of the first month
// of t's calendar quarter — Jan 1 / Apr 1 / Jul 1 / Oct 1.
fun (t Time) StartOfQuarter() Time {
    var q int = t.Quarter()
    var firstMonth int = (q - 1) * 3 + 1
    ret Date(t.Year(), firstMonth, 1, 0, 0, 0, 0)
}

// EndOfQuarter returns 23:59:59.999999999 on the last day of the
// last month of t's quarter — Mar 31 / Jun 30 / Sep 30 / Dec 31.
// Uses DaysInMonth for the day-31-vs-30 distinction.
fun (t Time) EndOfQuarter() Time {
    var q int = t.Quarter()
    var lastMonth int = q * 3
    var year int = t.Year()
    var day int = DaysInMonth(year, lastMonth)
    ret Date(year, lastMonth, day, 23, 59, 59, 999999999)
}

// StartOfWeek returns 00:00:00 on Monday of the ISO week containing
// t. Weeks start on Monday per ISO 8601, matching `ISOWeek()` /
// `DayOfWeekISO()` semantics. For t already on a Monday at 00:00,
// returns t (at the same instant). Useful for week-bucketing
// aggregations.
fun (t Time) StartOfWeek() Time {
    var iso int = t.DayOfWeekISO()
    var mon Time = t.AddDate(0, 0, -(iso - 1))
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = mon.ymd()
    ret Date(y, m, d, 0, 0, 0, 0)
}

// EndOfWeek returns 23:59:59.999999999 on Sunday of the ISO week
// containing t. Counterpart to StartOfWeek. Combine for an inclusive
// week-range filter.
fun (t Time) EndOfWeek() Time {
    var iso int = t.DayOfWeekISO()
    var sun Time = t.AddDate(0, 0, 7 - iso)
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = sun.ymd()
    ret Date(y, m, d, 23, 59, 59, 999999999)
}

// StartOfMonth returns 00:00:00 on the 1st of the calendar month
// containing t.
fun (t Time) StartOfMonth() Time {
    ret Date(t.Year(), t.Month(), 1, 0, 0, 0, 0)
}

// EndOfMonth returns 23:59:59.999999999 on the LAST day of the
// calendar month containing t — uses DaysInMonth to handle leap
// Februarys correctly.
fun (t Time) EndOfMonth() Time {
    var y int = t.Year()
    var m int = t.Month()
    var d int = DaysInMonth(y, m)
    ret Date(y, m, d, 23, 59, 59, 999999999)
}

// StartOfYear returns 00:00:00 on January 1 of the calendar year
// containing t.
fun (t Time) StartOfYear() Time {
    ret Date(t.Year(), 1, 1, 0, 0, 0, 0)
}

// EndOfYear returns 23:59:59.999999999 on December 31 of the
// calendar year containing t.
fun (t Time) EndOfYear() Time {
    ret Date(t.Year(), 12, 31, 23, 59, 59, 999999999)
}

// IsLeapDay reports whether t falls on February 29th (a date
// that only exists in leap years). Useful for handling
// birthday edge-cases, calendar UI highlighting.
fun (t Time) IsLeapDay() bool {
    if t.Month() != 2 { ret false }
    if t.Day() != 29 { ret false }
    ret true
}

// IsFirstDayOfMonth reports whether t falls on day 1 of its
// calendar month. Trivial helper; pairs with IsLastDayOfMonth
// for symmetric "start-of-period" / "end-of-period" predicates.
fun (t Time) IsFirstDayOfMonth() bool {
    if t.Day() == 1 { ret true }
    ret false
}

// IsFirstDayOfYear reports whether t falls on January 1.
fun (t Time) IsFirstDayOfYear() bool {
    if t.Month() == 1 {
        if t.Day() == 1 { ret true }
    }
    ret false
}

// IsLastDayOfYear reports whether t falls on December 31.
fun (t Time) IsLastDayOfYear() bool {
    if t.Month() == 12 {
        if t.Day() == 31 { ret true }
    }
    ret false
}

// IsLastDayOfMonth reports whether t falls on the last day of its
// calendar month. Useful for end-of-period rollups, "post on last
// day of month" scheduling.
fun (t Time) IsLastDayOfMonth() bool {
    if t.Day() == DaysInMonth(t.Year(), t.Month()) { ret true }
    ret false
}

// IsSameDay reports whether t and u fall on the same calendar
// day (year, month, day all match). Time-of-day differences are
// ignored. Useful for "did these events happen on the same day?"
// audits without fiddling with start-of-day boundaries.
fun (t Time) IsSameDay(u Time) bool {
    if t.daysSinceEpoch() == u.daysSinceEpoch() { ret true }
    ret false
}

// IsSameMonth reports whether t and u share the same calendar
// year AND month.
fun (t Time) IsSameMonth(u Time) bool {
    if t.Year() != u.Year() { ret false }
    if t.Month() != u.Month() { ret false }
    ret true
}

// IsSameYear reports whether t and u share the same calendar year.
fun (t Time) IsSameYear(u Time) bool {
    if t.Year() == u.Year() { ret true }
    ret false
}

// IsToday reports whether t falls on the same calendar day as the
// current wall-clock time. Compares (year, month, day) of t with
// `Now()` ignoring time-of-day. Useful for "show only today's
// entries" filters in logs / dashboards / scheduling UIs.
fun (t Time) IsToday() bool {
    var now Time = new Time { ns: Now() }
    ret t.IsSameDay(now)
}

// IsThisYear reports whether t falls in the same calendar year as
// the current wall-clock time. Useful for year-to-date aggregations
// and "this year" report filters.
fun (t Time) IsThisYear() bool {
    var now Time = new Time { ns: Now() }
    ret t.IsSameYear(now)
}

// IsThisMonth reports whether t falls in the same calendar
// (year, month) as the current wall-clock time. Useful for
// month-to-date aggregations, billing-cycle filters.
fun (t Time) IsThisMonth() bool {
    var now Time = new Time { ns: Now() }
    ret t.IsSameMonth(now)
}

// IsThisWeek reports whether t falls in the same ISO 8601 week
// (i.e. same iso year + same iso week number) as the current
// wall-clock time. Weeks start Monday per ISO; the boundary
// behavior matches `ISOWeek()` so Sunday Jan 1 — say 2023-01-01 —
// belongs to the previous calendar year's ISO week. Useful for
// weekly-rollup dashboards.
fun (t Time) IsThisWeek() bool {
    var now Time = new Time { ns: Now() }
    if t.ISOWeekYear() != now.ISOWeekYear() { ret false }
    if t.ISOWeek() != now.ISOWeek() { ret false }
    ret true
}

// IsBetween reports whether t falls within the closed interval
// [lo, hi]. Returns false if lo > hi (degenerate interval). Useful
// for event-window checks, schedule eligibility, log-filter ranges.
fun (t Time) IsBetween(lo Time, hi Time) bool {
    if lo.ns > hi.ns { ret false }
    if t.ns < lo.ns { ret false }
    if t.ns > hi.ns { ret false }
    ret true
}

// AddMillis returns t + n milliseconds. Negative n shifts backward.
// Convenience over `t.Add(n * 1000000)`.
fun (t Time) AddMillis(n int) Time {
    var r Time = new Time {ns: t.ns + n * 1000000}
    ret r
}

// AddSeconds returns t + n seconds.
fun (t Time) AddSeconds(n int) Time {
    var r Time = new Time {ns: t.ns + n * 1000000000}
    ret r
}

// AddMinutes returns t + n minutes.
fun (t Time) AddMinutes(n int) Time {
    var r Time = new Time {ns: t.ns + n * 60000000000}
    ret r
}

// AddHours returns t + n hours.
fun (t Time) AddHours(n int) Time {
    var r Time = new Time {ns: t.ns + n * 3600000000000}
    ret r
}

// AddDays returns t + n civil days at the same wall-clock time.
// Convenience over `t.AddDate(0, 0, n)`. Handles month / year
// rollover via the existing AddDate path.
fun (t Time) AddDays(n int) Time {
    ret t.AddDate(0, 0, n)
}

// AddWeeks returns t + n calendar weeks at the same wall-clock time.
// Convenience over `t.AddDate(0, 0, n * 7)`.
fun (t Time) AddWeeks(n int) Time {
    ret t.AddDate(0, 0, n * 7)
}

// AddMonths returns t + n calendar months at the same day-of-month
// and wall-clock time. Routes through AddDate which uses Hinnant's
// algorithm — day overflow normalizes naturally (Jan 31 + 1 month
// is interpreted as "Feb 31", which day-arithmetic resolves to
// early March rather than clamping). Callers wanting clamping
// semantics should check `Month()` after the call.
fun (t Time) AddMonths(n int) Time {
    ret t.AddDate(0, n, 0)
}

// AddYears returns t + n calendar years at the same date/time.
// Feb 29 + 1 year overflows similarly: 2024-02-29 + 1y resolves to
// 2025-03-01 (Feb 29 → Feb 28 + 1, then "+1" pushes to Mar 1).
fun (t Time) AddYears(n int) Time {
    ret t.AddDate(n, 0, 0)
}

// SecondsBetween returns the number of whole seconds from u to t
// (floor-div on the nanosecond difference). Completes the
// floor-div between-quartet alongside Minutes/Hours/Days. Useful
// for short-interval throttling, "X seconds ago" formatting.
fun (t Time) SecondsBetween(u Time) int {
    var d int = t.ns - u.ns
    ret floorDiv(d, 1000000000)
}

// HoursBetween returns the number of whole hours from u to t
// (floor-div on the nanosecond difference). Positive when t is
// later than u, negative when earlier. Useful for "X hours ago"
// labels, hourly bucket aggregation.
fun (t Time) HoursBetween(u Time) int {
    var d int = t.ns - u.ns
    ret floorDiv(d, 3600000000000)
}

// MinutesBetween returns the number of whole minutes from u to t
// (floor-div on the nanosecond difference). Useful for log
// throttling, "X minutes ago" UI, minute-bucket aggregation.
fun (t Time) MinutesBetween(u Time) int {
    var d int = t.ns - u.ns
    ret floorDiv(d, 60000000000)
}

// DaysBetween returns the number of civil days from u to t,
// counting only whole days (floor-division of the nanosecond
// difference). Positive when t is later than u, negative when
// earlier. Useful for "X days ago" / "Y days until" calculations
// without dealing with nanosecond Sub.
fun (t Time) DaysBetween(u Time) int {
    ret t.daysSinceEpoch() - u.daysSinceEpoch()
}

// WeeksBetween returns the number of whole 7-day weeks from u to t
// via `DaysBetween(u) / 7`. Floored toward zero (volt's int division
// semantics), so partial weeks drop. Sign mirrors DaysBetween.
// Useful for "X weeks ago" / age-in-weeks displays.
fun (t Time) WeeksBetween(u Time) int {
    ret t.DaysBetween(u) / 7
}

// MonthsBetween returns the number of whole calendar months from u
// to t. Computed as `(t.Year - u.Year) * 12 + (t.Month - u.Month)`,
// then adjusted down by 1 when t's day-of-month is earlier than u's
// (a "partial month" at the end is not counted). Sign mirrors the
// year/month difference. Useful for subscription / age-in-months /
// retention-cohort calculations without nanosecond arithmetic.
fun (t Time) MonthsBetween(u Time) int {
    var diff int = (t.Year() - u.Year()) * 12 + (t.Month() - u.Month())
    if diff > 0 {
        if t.Day() < u.Day() { diff = diff - 1 }
    }
    if diff < 0 {
        if t.Day() > u.Day() { diff = diff + 1 }
    }
    ret diff
}

// NextWeekday returns the next occurrence of weekday w (0=Sun..
// 6=Sat) strictly AFTER t (calendar-day). If t already falls on w
// it advances by 7 days. w out of [0, 6] is reduced modulo 7
// (negative inputs flipped to positive). Useful for scheduling:
// "next Monday at 9am" patterns.
fun (t Time) NextWeekday(w int) Time {
    var target int = w % 7
    if target < 0 { target = target + 7 }
    var cur int = t.Weekday()
    var diff int = target - cur
    if diff <= 0 { diff = diff + 7 }
    ret t.AddDate(0, 0, diff)
}

// PrevWeekday returns the previous occurrence of weekday w (0..6)
// strictly BEFORE t. If t already falls on w it rewinds by 7 days.
fun (t Time) PrevWeekday(w int) Time {
    var target int = w % 7
    if target < 0 { target = target + 7 }
    var cur int = t.Weekday()
    var diff int = cur - target
    if diff <= 0 { diff = diff + 7 }
    ret t.AddDate(0, 0, -diff)
}

// Yesterday returns t minus 1 calendar day at the same wall-clock
// time. Convenience wrapper around AddDate(0, 0, -1). Useful for
// "show me yesterday's data" reports / sliding 24-hour windows.
fun (t Time) Yesterday() Time {
    ret t.AddDate(0, 0, -1)
}

// Tomorrow returns t plus 1 calendar day at the same wall-clock
// time. Counterpart to Yesterday.
fun (t Time) Tomorrow() Time {
    ret t.AddDate(0, 0, 1)
}

// IsWeekend reports whether t falls on Saturday or Sunday.
fun (t Time) IsWeekend() bool {
    var w int = t.Weekday()
    if w == 0 { ret true }   // Sunday
    if w == 6 { ret true }   // Saturday
    ret false
}

// IsWeekday reports whether t falls on Monday through Friday.
fun (t Time) IsWeekday() bool {
    if t.IsWeekend() { ret false }
    ret true
}

// AddBusinessDays returns t advanced by n business (Mon-Fri) days.
// n > 0 moves forward, n < 0 backward, n == 0 returns t unchanged.
// Weekends are skipped during traversal. Time-of-day preserved.
fun (t Time) AddBusinessDays(n int) Time {
    var d Time = t
    if n > 0 {
        var k int = n
        for k > 0 {
            d = d.AddDate(0, 0, 1)
            if !d.IsWeekend() { k = k - 1 }
        }
    }
    if n < 0 {
        var k int = -n
        for k > 0 {
            d = d.AddDate(0, 0, -1)
            if !d.IsWeekend() { k = k - 1 }
        }
    }
    ret d
}

// BusinessDaysBetween returns the number of weekdays (Mon-Fri) in
// the half-open range (u, t]. Positive when t is after u, negative
// when before, zero when same day. Useful for SLA-day counting,
// trading-day intervals.
fun (t Time) BusinessDaysBetween(u Time) int {
    var diff int = t.DaysBetween(u)
    if diff == 0 { ret 0 }
    var sign int = 1
    if diff < 0 { sign = -1 }
    var steps int = diff
    if steps < 0 { steps = -steps }
    var count int = 0
    var cursor Time = u
    var i int = 0
    for i < steps {
        cursor = cursor.AddDate(0, 0, sign)
        if !cursor.IsWeekend() { count = count + 1 }
        i = i + 1
    }
    ret count * sign
}

// NextBusinessDay returns the next non-weekend day strictly AFTER t.
// Skips Saturday and Sunday — Friday → Monday, Saturday → Monday,
// any other day → next day. Time-of-day preserved. Useful for
// "due-date will-be-business-day" workflows.
fun (t Time) NextBusinessDay() Time {
    var d Time = t.AddDate(0, 0, 1)
    for d.IsWeekend() {
        d = d.AddDate(0, 0, 1)
    }
    ret d
}

// PrevBusinessDay returns the previous non-weekend day strictly
// BEFORE t. Counterpart to NextBusinessDay — Monday → Friday.
fun (t Time) PrevBusinessDay() Time {
    var d Time = t.AddDate(0, 0, -1)
    for d.IsWeekend() {
        d = d.AddDate(0, 0, -1)
    }
    ret d
}

// IsLeapYear reports whether the given proleptic Gregorian year is
// a leap year — divisible by 4, EXCEPT centuries unless divisible
// by 400. Year 2000 is a leap year, 1900 is not, 2024 is, 2023 isn't.
fun IsLeapYear(year int) bool {
    if (year % 4) != 0 { ret false }
    if (year % 100) != 0 { ret true }
    if (year % 400) == 0 { ret true }
    ret false
}

// DaysInMonth returns the number of days in (year, month) for the
// proleptic Gregorian calendar. month must be 1..12; out-of-range
// returns 0. Handles February leap-year logic via IsLeapYear.
fun DaysInMonth(year int, month int) int {
    if month < 1 { ret 0 }
    if month > 12 { ret 0 }
    if month == 1 { ret 31 }
    if month == 2 {
        if IsLeapYear(year) { ret 29 }
        ret 28
    }
    if month == 3 { ret 31 }
    if month == 4 { ret 30 }
    if month == 5 { ret 31 }
    if month == 6 { ret 30 }
    if month == 7 { ret 31 }
    if month == 8 { ret 31 }
    if month == 9 { ret 30 }
    if month == 10 { ret 31 }
    if month == 11 { ret 30 }
    ret 31
}

// DaysInThisMonth returns the day count in t's calendar month —
// e.g. 31 for May, 28 or 29 for February depending on leap year.
// Wrapper over `DaysInMonth(t.Year(), t.Month())`.
fun (t Time) DaysInThisMonth() int {
    ret DaysInMonth(t.Year(), t.Month())
}

// DaysInYear returns 366 if year is a leap year, 365 otherwise.
// Useful for capacity calculations / year-progress bars.
fun DaysInYear(year int) int {
    if IsLeapYear(year) { ret 366 }
    ret 365
}

// DaysInThisYear returns the day count in t's calendar year — 365
// or 366. Wrapper over `DaysInYear(t.Year())`.
fun (t Time) DaysInThisYear() int {
    ret DaysInYear(t.Year())
}

// YearDay returns the day of the year, 1..366 (366 only in a leap
// year). Jan 1 is day 1; Dec 31 is 365 (non-leap) or 366 (leap).
fun (t Time) YearDay() int {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.ymd()
    if d < 0 { ret 0 }   // dead use to satisfy checker
    if m < 0 { ret 0 }
    var thisDay int = t.daysSinceEpoch()
    var yearStart int = daysFromCivil(y, 1, 1)
    ret thisDay - yearStart + 1
}

// isoLastWeekOf returns the number of ISO 8601 weeks in calendar
// year y (52 or 53). Used by the ISOWeek / ISOWeekYear pair.
// Always equals the ISO week of Dec 28 of that year (Dec 28 is
// guaranteed to fall in the last ISO week).
fun isoLastWeekOf(y int) int {
    var days int = daysFromCivil(y, 12, 28)
    var yearStart int = daysFromCivil(y, 1, 1)
    var ord int = days - yearStart + 1
    var wd0 int = (days + 4) % 7
    if wd0 < 0 { wd0 = wd0 + 7 }
    var wd int = wd0
    if wd == 0 { wd = 7 }
    ret (10 + ord - wd) / 7
}

// isoYearWeek returns the (iso_year, iso_week) pair for (y, m, d).
// iso_year may be y-1 (early January dates) or y+1 (late December
// dates) when the calendar week straddles a year boundary.
fun isoYearWeek(y int, m int, d int) (int, int) {
    var days int = daysFromCivil(y, m, d)
    var yearStart int = daysFromCivil(y, 1, 1)
    var ord int = days - yearStart + 1
    var wd0 int = (days + 4) % 7
    if wd0 < 0 { wd0 = wd0 + 7 }
    var wd int = wd0
    if wd == 0 { wd = 7 }
    var w int = (10 + ord - wd) / 7
    if w < 1 {
        ret y - 1, isoLastWeekOf(y - 1)
    }
    if w > isoLastWeekOf(y) {
        ret y + 1, 1
    }
    ret y, w
}

// ISOWeek returns the ISO 8601 week number (1..53). Weeks start
// on Monday; week 1 is the week containing the first Thursday of
// the year (equivalently: the week containing January 4). Dates
// in early January may belong to the last week (52 or 53) of the
// previous year; late-December dates may belong to week 1 of the
// next year — use ISOWeekYear() for the matching year.
fun (t Time) ISOWeek() int {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.ymd()
    if y < 0 { ret 0 }                                      // dead use to satisfy checker
    var iy int = 0
    var iw int = 0
    iy, iw = isoYearWeek(y, m, d)
    if iy < 0 { ret 0 }                                     // dead use to satisfy checker
    ret iw
}

// ISOWeekYear returns the ISO 8601 week-numbering year for t. This
// equals the calendar Year() for most dates, but may differ by one
// for dates near a year boundary (e.g. 2027-01-01 is a Friday — it
// belongs to ISO week 53 of 2026, so ISOWeekYear() returns 2026
// while Year() returns 2027).
fun (t Time) ISOWeekYear() int {
    var y int = 0
    var m int = 0
    var d int = 0
    y, m, d = t.ymd()
    if y < 0 { ret 0 }                                      // dead use to satisfy checker
    var iy int = 0
    var iw int = 0
    iy, iw = isoYearWeek(y, m, d)
    if iw < 0 { ret 0 }                                     // dead use to satisfy checker
    ret iy
}

// MonthName returns the English name of the month for m in 1..12.
// Out-of-range returns "" so callers can detect bad input.
fun MonthName(month int) string {
    if month == 1 { ret "January" }
    if month == 2 { ret "February" }
    if month == 3 { ret "March" }
    if month == 4 { ret "April" }
    if month == 5 { ret "May" }
    if month == 6 { ret "June" }
    if month == 7 { ret "July" }
    if month == 8 { ret "August" }
    if month == 9 { ret "September" }
    if month == 10 { ret "October" }
    if month == 11 { ret "November" }
    if month == 12 { ret "December" }
    ret ""
}

// MonthAbbrev returns the three-letter English abbreviation of the
// month for m in 1..12 — "Jan", "Feb", "Mar", "Apr", "May", "Jun",
// "Jul", "Aug", "Sep", "Oct", "Nov", "Dec". Out-of-range returns "".
// Useful for compact date display in log lines, condensed timestamp
// formats, calendar tables.
fun MonthAbbrev(month int) string {
    if month == 1 { ret "Jan" }
    if month == 2 { ret "Feb" }
    if month == 3 { ret "Mar" }
    if month == 4 { ret "Apr" }
    if month == 5 { ret "May" }
    if month == 6 { ret "Jun" }
    if month == 7 { ret "Jul" }
    if month == 8 { ret "Aug" }
    if month == 9 { ret "Sep" }
    if month == 10 { ret "Oct" }
    if month == 11 { ret "Nov" }
    if month == 12 { ret "Dec" }
    ret ""
}

// WeekdayName returns the full English name of the weekday for w in
// 0..6 (Sun=0, Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6). Matches
// the Weekday()-method output convention. Out-of-range returns "".
fun WeekdayName(w int) string {
    if w == 0 { ret "Sunday" }
    if w == 1 { ret "Monday" }
    if w == 2 { ret "Tuesday" }
    if w == 3 { ret "Wednesday" }
    if w == 4 { ret "Thursday" }
    if w == 5 { ret "Friday" }
    if w == 6 { ret "Saturday" }
    ret ""
}

// WeekdayAbbrev returns the three-letter English abbreviation of the
// weekday for w in 0..6 — "Sun", "Mon", "Tue", "Wed", "Thu", "Fri",
// "Sat". Out-of-range returns "". Pairs with MonthAbbrev for compact
// date display: `WeekdayAbbrev(2) + " " + MonthAbbrev(5)` → "Tue May".
fun WeekdayAbbrev(w int) string {
    if w == 0 { ret "Sun" }
    if w == 1 { ret "Mon" }
    if w == 2 { ret "Tue" }
    if w == 3 { ret "Wed" }
    if w == 4 { ret "Thu" }
    if w == 5 { ret "Fri" }
    if w == 6 { ret "Sat" }
    ret ""
}

// IsZero reports whether t is the zero Time value (ns == 0, which
// corresponds to the Unix epoch — Jan 1 1970 00:00:00 UTC). Useful
// for detecting uninitialized Time values, though note that a real
// Time at the exact epoch also returns true (rare in practice).
fun (t Time) IsZero() bool {
    if t.ns == 0 { ret true }
    ret false
}

// Equal reports whether t and u represent the same instant (same
// nanosecond value). Equivalent to `t.Sub(u) == 0` but reads more
// naturally at call sites.
fun (t Time) Equal(u Time) bool {
    if t.ns == u.ns { ret true }
    ret false
}

// IsFuture reports whether t is strictly after the current wall-clock
// time. Convenience over `t.ns > Now()`. Useful for TTL / expiry
// checks ("is the cached value still valid?", "has the rate-limit
// window passed?"). Equal-to-now → false (matches strict semantics
// of Before/After elsewhere).
fun (t Time) IsFuture() bool {
    if t.ns > Now() { ret true }
    ret false
}

// IsPast reports whether t is strictly before the current wall-clock
// time. Convenience over `t.ns < Now()`. Useful for staleness
// checks ("is this token expired?", "did this deadline already pass?").
// Equal-to-now → false.
fun (t Time) IsPast() bool {
    if t.ns < Now() { ret true }
    ret false
}

// IsLeapYear reports whether t's year is a leap year. Convenience
// over `time.IsLeapYear(t.Year())`.
fun (t Time) IsLeapYear() bool {
    ret IsLeapYear(t.Year())
}
