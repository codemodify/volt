// run f(a, b, c, d) — 4-arg spawn smoke test.
// Worker reads N ints from `jobs`, multiplies each by `scale`, writes
// to `results`, and signals `done`. Pass everything via the spawn call.
// Sum of 1..6 = 21; * 2 = 42.

package main

fun worker(jobs chan int, results chan int, scale int, done chan int) {
    var i int = 0
    for i < 6 {
        var v int = read(jobs)
        write(results, v * scale)
        i = i + 1
    }
    write(done, 1)
}

fun main() int {
    var jobs    chan int = new(8) chan int
    var results chan int = new(8) chan int
    var done    chan int = new(1) chan int

    var i int = 1
    for i <= 6 {
        write(jobs, i)
        i = i + 1
    }

    run worker(jobs, results, 2, done)
    read(done)

    var sum int = 0
    var j int = 0
    for j < 6 {
        sum = sum + read(results)
        j = j + 1
    }
    ret sum
}
