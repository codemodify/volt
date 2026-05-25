// run f(a, b, c, d) — 4-arg spawn smoke test.
// Worker reads N ints from `jobs`, multiplies each by `scale`, writes
// to `results`, and signals `done`. Pass everything via the spawn call.
// Sum of 1..6 = 21; * 2 = 42.

package main

fun worker(jobs chan int, results chan int, scale int, done chan int) {
    for i := 0; i < 6; i++ {
        var v int = read(jobs)
        write(results, v * scale)
    }
    write(done, 1)
}

fun main() int {
    var jobs    chan int = new(8) chan int
    var results chan int = new(8) chan int
    var done    chan int = new(1) chan int

    for i := 1; i <= 6; i++ {
        write(jobs, i)
    }

    run worker(jobs, results, 2, done)
    read(done)

    var sum int = 0
    for j := 0; j < 6; j++ {
        sum = sum + read(results)
    }
    ret sum
}
