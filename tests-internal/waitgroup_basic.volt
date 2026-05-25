// waitgroup smoke test — main spawns N workers, each Add(1)s
// implicitly (via main pre-Add(N)), Done()s when finished. Main
// calls Wait() to block until counter hits 0. Exit 42 = success.

package main

fun worker(wg waitgroup, sum atomic int) {
    sum.Add(1)
    wg.Done()
}

fun main() int {
    var wg waitgroup = new()
    var sum atomic int = new{}

    var i int = 0
    for i < 100 {
        wg.Add(1)
        run worker(wg, sum)
        i = i + 1
    }

    wg.Wait()                    // block until all 100 Done()s have happened

    if sum.Load() == 100 {
        ret 42
    }
    ret 0
}
