// channels (single-threaded — producer fills, consumer drains).
// Push 1..6 into a bounded channel of capacity 8.
// Then drain and sum. 1+2+3+4+5+6 = 21. Multiply by 2 = 42.

package main

fun main() int {
    var ch chan int = new(8) chan int

    var i int = 1
    for i <= 6 {
        write(ch, i)
        i = i + 1
    }

    var sum int = 0
    var j int = 0
    for j < 6 {
        sum = sum + read(ch)
        j = j + 1
    }

    ret sum * 2
}
