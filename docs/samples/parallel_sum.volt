// parallel_sum — divide-and-conquer summation across N workers.
// Demonstrates the concurrency primitives: `run` spawns an OS
// thread, `chan1N` carries partial results, `atomic` and
// `waitgroup` are NOT needed here because the channel send / read
// happens-before edge already orders the writes.
//
// Run it: `volt run docs/samples/parallel_sum.volt`. The program
// computes sum(0..999) = 499500 in ~5 ms on 4 parallel workers.

package main

import "log"

fun worker(lo int, hi int, out chan write int) {
    var s int = 0
    for i := lo; i < hi; i++ {
        s = s + i
    }
    write(out, s)
}

fun main() int {
    var total int = 1000
    var workers int = 4
    var chunk int = total / workers

    // chan1N — many writers, one reader (main).
    var partials chan1N int = new(workers)

    for w := range workers {
        var lo int = w * chunk
        var hi int = lo + chunk
        run worker(lo, hi, partials)
    }

    // Drain the partials.
    var sum int = 0
    for w := range workers {
        sum = sum + read(partials)
        if w < 0 { sum = sum }   // dead use to keep w live
    }

    var expected int = (total * (total - 1)) / 2
    log.Println("parallel_sum = %d (expected %d)", sum, expected)
    if sum == expected { ret 42 }
    ret 0
}
