// time.Time: construction, decomposition into Y/M/D/H/M/S, RFC3339
// Format. Uses Howard Hinnant's day algorithm. UTC only.

package main

import "time"
import "log"

fun main() int {
    var pass int = 0

    // Reference instant: 2024-05-25 14:30:00 UTC.
    // Unix seconds = 1716647400 (sanity-checked against `date -d`).
    var t1 Time = time.Unix(1716647400, 0)

    if t1.Year() == 2024 { pass = pass + 1 }
    if t1.Month() == 5 { pass = pass + 1 }
    if t1.Day() == 25 { pass = pass + 1 }
    if t1.Hour() == 14 { pass = pass + 1 }
    if t1.Minute() == 30 { pass = pass + 1 }
    if t1.Second() == 0 { pass = pass + 1 }

    var s string = t1.Format()
    if s == "2024-05-25T14:30:00Z" { pass = pass + 1 }

    // Epoch itself: 1970-01-01T00:00:00Z.
    var t0 Time = time.Unix(0, 0)
    if t0.Format() == "1970-01-01T00:00:00Z" { pass = pass + 1 }

    // Add 1 day worth of nanoseconds.
    var t2 Time = t0.Add(86400 * 1000000000)
    if t2.Format() == "1970-01-02T00:00:00Z" { pass = pass + 1 }

    // Sub: difference back to t0 should be 86400 * 1e9 nanoseconds.
    var diff int = t2.Sub(t0)
    if diff == 86400000000000 { pass = pass + 1 }

    // Before / After.
    if t0.Before(t2) { pass = pass + 1 }
    if t2.After(t0) { pass = pass + 1 }

    // Far-future spot check: 2100-12-31T23:59:59 = 4133980799 unix sec.
    var t3 Time = time.Unix(4133980799, 0)
    if t3.Format() == "2100-12-31T23:59:59Z" { pass = pass + 1 }

    log.Println("pass=%d/13", pass)
    if pass == 13 { ret 42 }
    ret 0
}
