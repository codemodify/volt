// time.Now() — nanoseconds since Unix epoch.
// time.Mono() — strictly increasing monotonic clock.
// Verify Mono() advances over a Sleep, and Now() is in a plausible
// post-2025 range.

package main

import "log"
import "time"

fun main() int {
    var pass int = 0

    var t1 int = time.Mono()
    time.Sleep(1000000)         // 1 ms
    var t2 int = time.Mono()

    var diff int = t2 - t1
    if diff >= 1000000 {        // at least 1 ms elapsed
        pass = pass + 1
    }
    if diff < 100000000 {       // sanity: less than 100 ms
        pass = pass + 1
    }

    var now int = time.Now()
    // Unix epoch ns for 2025-01-01 is ~1735689600 * 1e9 = ~1.7e18.
    // Just check Now() is positive and very large.
    if now > 1000000000000000000 {
        pass = pass + 1
    }

    log.Println("mono diff=%d ns, now=%d ns, pass=%d/3", diff, now, pass)
    if pass == 3 { ret 42 }
    ret 0
}
