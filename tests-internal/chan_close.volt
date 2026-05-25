// close(ch) + two-value receive detects drained-and-closed.
// Producer sends 5 numbers then closes.
// Consumer reads with `v, ok := read(ch)` until ok==false.
// Sum 1..5 = 15. Multiply by 3 = 45. Subtract 3 = 42.

package main

fun producer(out chan int) {
    var i int = 1
    for i <= 5 {
        write(out, i)
        i = i + 1
    }
    close(out)
}

fun consumer(in chan int, done chan int) {
    var sum int = 0
    for {
        v, ok := read(in)
        if !ok {
            break
        }
        sum = sum + v
    }
    write(done, sum)
}

fun main() int {
    var ch chan int = new(2) chan int
    var done chan int = new(1) chan int
    run producer(ch)
    run consumer(ch, done)
    var total int = read(done)
    ret total * 3 - 3
}
