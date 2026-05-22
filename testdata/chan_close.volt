// Phase 3: close(ch) + two-value receive detects drained-and-closed.
// Producer sends 5 numbers then closes.
// Consumer reads with `v, ok := <-ch` until ok==false.
// Sum 1..5 = 15. Multiply by 3 = 45. Subtract 3 = 42.

package main

fun producer(out chan int) {
    var i int = 1
    for i <= 5 {
        out <- i
        i = i + 1
    }
    close(out)
}

fun consumer(in chan int, done chan int) {
    var sum int = 0
    for {
        v, ok := <-in
        if !ok {
            break
        }
        sum = sum + v
    }
    done <- sum
}

fun main() int {
    var ch chan int = new chan int(2)
    var done chan int = new chan int(1)
    run producer(ch)
    run consumer(ch, done)
    var total int = <-done
    ret total * 3 - 3
}
