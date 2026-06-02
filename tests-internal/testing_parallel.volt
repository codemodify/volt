// testing.RunParallel smoke: three tests sleep 100ms each; total
// wall time must be well under their sum (300ms) — proving they
// ran on separate threads. Exit 42 = parallel-passed.

package main

import "log"
import "testing"
import "time"

fun TestSleepA(t *T) {
    t.Parallel()
    time.Sleep(100000000)
}

fun TestSleepB(t *T) {
    t.Parallel()
    time.Sleep(100000000)
}

fun TestSleepC(t *T) {
    t.Parallel()
    time.Sleep(100000000)
}

fun main() int {
    var tests []NamedTest = new(3) []NamedTest {}
    tests[0] = testing.NewNamedTest("TestSleepA", TestSleepA)
    tests[1] = testing.NewNamedTest("TestSleepB", TestSleepB)
    tests[2] = testing.NewNamedTest("TestSleepC", TestSleepC)

    var t0 int = time.Mono()
    var passed int = testing.RunParallel(tests)
    var elapsed int = time.Mono() - t0
    // 3 * 100ms = 300ms sequential. Parallel should be ~100ms; allow
    // generous 250ms ceiling for thread-startup overhead on slow CI.
    var elapsedMs int = elapsed / 1000000
    log.Println("RunParallel: %d passed in %d ms", passed, elapsedMs)
    if passed != 3 { ret 0 }
    if elapsedMs >= 250 { ret 0 }
    ret 42
}
