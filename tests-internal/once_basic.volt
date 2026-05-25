// once smoke test — N threads each call init_thing(); only ONE of
// them runs the actual init body. Use an atomic to count the runs;
// expect exactly 1. Exit 42 = success.

package main

fun candidate(o once, runs atomic int, wg waitgroup) {
    if o.Begin() == 1 {
        // Only the first caller reaches this. Subsequent callers
        // block inside Begin() until Done() below.
        runs.Add(1)
        o.Done()
    }
    // After here, every thread (first OR subsequent) has observed
    // a completed initialization.
    wg.Done()
}

fun main() int {
    var o once = new()
    var runs atomic int = new{}
    var wg waitgroup = new()

    var i int = 0
    for i < 20 {
        wg.Add(1)
        run candidate(o, runs, wg)
        i = i + 1
    }
    wg.Wait()

    if runs.Load() == 1 {
        ret 42
    }
    ret 0
}
