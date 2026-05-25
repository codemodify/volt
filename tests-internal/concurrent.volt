// real producer/consumer in separate threads.
//
// `producer` sends 6 ints into ch.
// `consumer` drains 6 ints from ch, sums them, sends sum on done.
// main spawns both and blocks on the done channel.
// Sum 1..6 = 21 → exit 21*2 = 42.
//
// The producer-consumer pair runs on TWO separate OS threads spawned via
// clone(); blocking on the bounded channel synchronizes them via futex.

package main

fun producer(ch chan int) {
    var i int = 1
    for i <= 6 {
        write(ch, i)
        i = i + 1
    }
}

fun consumer(in chan int, done chan int) {
    var sum int = 0
    var j int = 0
    for j < 6 {
        sum = sum + read(in)
        j = j + 1
    }
    write(done, sum)
}

fun main() int {
    var ch chan int = new(2) chan int      // small buffer → forces blocking
    var done chan int = new(1) chan int
    run producer(ch)
    run consumer(ch, done)
    var total int = read(done)
    ret total * 2
}
