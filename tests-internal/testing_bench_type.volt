// testing.B type smoke test: construct a B manually and verify the
// accessors work. The benchmark *harness* (RunBenchmark) loops for
// ~1 sec calibrating N, which is too slow for the regression suite —
// it's exercised via /tmp tests under `volt test` instead.

package main

import "testing"
import "log"

fun main() int {
    // Constructor + accessors.
    var b *B = new B {name: "manual", N: 1000, nsElapsed: 0}
    if b.Name() != "manual" {
        log.Println("Name() broken")
        ret 0
    }
    if b.NsElapsed() != 0 {
        log.Println("NsElapsed() initial mismatch")
        ret 0
    }

    // Default benchmark time should be 1 sec = 1e9 ns.
    if testing.BenchTimeNs() != 1000000000 {
        log.Println("BenchTimeNs() default mismatch")
        ret 0
    }

    // Use N inside a quick loop so the type integrates with normal
    // arithmetic.
    var sum int = 0
    for i:=0; i < b.N; i++ {
        sum = sum + i
    }
    if sum != 499500 {            // sum 0..999
        log.Println("sum wrong: %d", sum)
        ret 0
    }

    log.Println("testing.B smoke ok")
    ret 42
}
