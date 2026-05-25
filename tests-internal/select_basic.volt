// select picks the ready case.
// Producer fills ch first; main selects between ch and a "never ready" channel.
// The ch case wins. 6*7 = 42.

package main

fun producer(ch chan int) {
    write(ch, 6)
}

fun main() int {
    var ch chan int = new(1) chan int
    var idle chan int = new(1) chan int
    run producer(ch)

    var got int = 0
    select {
    case v := read(ch):
        got = v * 7
    case w := read(idle):
        got = w * 100
    }
    ret got
}
