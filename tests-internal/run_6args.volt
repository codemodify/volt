package main
fun worker(jobs chan int, results chan int, scale int, offset int, repeat int, done chan int) {
    for i := 0; i < repeat; i++ {
        var v int = read(jobs)
        write(results, v * scale + offset)
    }
    write(done, 1)
}

fun main() int {
    var jobs    chan int = new(8)
    var results chan int = new(8)
    var done    chan int = new()
    for i := 1; i <= 4; i++ {
        write(jobs, i)
    }
    run worker(jobs, results, 10, 1, 4, done)   // 6 args
    read(done)
    var sum int = 0
    for j := 0; j < 4; j++ {
        sum = sum + read(results)
    }
    // values: 11, 21, 31, 41  → sum = 104. main ret 104 - 62 = 42.
    ret sum - 62
}
