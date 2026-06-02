// time.ParseRFC3339 round-trip + validation smoke.

package main

import "time"
import "log"

fun main() int {
    var pass int = 0

    // Round-trip: epoch
    var epoch time.Time = new time.Time {}
    var ep time.Time = new time.Time {}
    var err error = nil
    ep, err = time.ParseRFC3339("1970-01-01T00:00:00Z")
    if err == nil {
        if ep.UnixNano() == 0 { pass = pass + 1 }
        if ep.Format() == "1970-01-01T00:00:00Z" { pass = pass + 1 }
    }
    if epoch.UnixNano() == 0 { pass = pass + 1 }   // dead use

    // Y2024 date
    var t1 time.Time = new time.Time {}
    var e1 error = nil
    t1, e1 = time.ParseRFC3339("2024-05-25T14:30:00Z")
    if e1 == nil {
        if t1.Year()   == 2024 { pass = pass + 1 }
        if t1.Month()  == 5    { pass = pass + 1 }
        if t1.Day()    == 25   { pass = pass + 1 }
        if t1.Hour()   == 14   { pass = pass + 1 }
        if t1.Minute() == 30   { pass = pass + 1 }
        if t1.Second() == 0    { pass = pass + 1 }
        if t1.Format() == "2024-05-25T14:30:00Z" { pass = pass + 1 }
    }

    // End-of-year boundary
    var t2 time.Time = new time.Time {}
    var e2 error = nil
    t2, e2 = time.ParseRFC3339("2100-12-31T23:59:59Z")
    if e2 == nil {
        if t2.Format() == "2100-12-31T23:59:59Z" { pass = pass + 1 }
    }

    // Pre-epoch
    var t3 time.Time = new time.Time {}
    var e3 error = nil
    t3, e3 = time.ParseRFC3339("1965-06-15T12:00:00Z")
    if e3 == nil {
        if t3.Format() == "1965-06-15T12:00:00Z" { pass = pass + 1 }
        if t3.UnixNano() < 0 { pass = pass + 1 }
    }

    // Error: wrong length
    var t4 time.Time = new time.Time {}
    var e4 error = nil
    t4, e4 = time.ParseRFC3339("2024-05-25")
    if e4 != nil { pass = pass + 1 }
    if t4.UnixNano() == 0 { pass = pass + 1 }   // zero-value on error

    // Error: missing 'T'
    var t5 time.Time = new time.Time {}
    var e5 error = nil
    t5, e5 = time.ParseRFC3339("2024-05-25 14:30:00Z")
    if e5 != nil { pass = pass + 1 }
    if t5.UnixNano() == 0 { pass = pass + 1 }

    // Error: non-digit in seconds
    var t6 time.Time = new time.Time {}
    var e6 error = nil
    t6, e6 = time.ParseRFC3339("2024-05-25T14:30:0XZ")
    if e6 != nil { pass = pass + 1 }
    if t6.UnixNano() == 0 { pass = pass + 1 }

    // Error: out-of-range month
    var t7 time.Time = new time.Time {}
    var e7 error = nil
    t7, e7 = time.ParseRFC3339("2024-13-25T14:30:00Z")
    if e7 != nil { pass = pass + 1 }
    if t7.UnixNano() == 0 { pass = pass + 1 }

    log.Println("pass=%d/21", pass)
    if pass == 21 { ret 42 }
    ret 0
}
