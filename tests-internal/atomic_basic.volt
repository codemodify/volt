// atomic primitive smoke test — two threads each Add(1) 1000 times.
// Final value via Read() should equal 2000. Exit 42 = success.
//
// Tests:
//   - var x atomic int = new {} (zero-init) or new {5} (initial value)
//   - passing atomic handle to a thread (reference-typed)
//   - a.Add(1) under contention
//   - a.Read() returns the final value

package main

fun bumper(a atomic int, done chan int) {
    for i := 0; i < 1000; i++ {
        a.Add(1)
    }
    write(done, 1)
}

fun main() int {
    var a atomic int = new {}
    var done chan int = new(2) chan int
    run bumper(a, done)
    run bumper(a, done)
    read(done)
    read(done)
    var final int = a.Read()
    if final == 2000 {
        ret 42
    }
    ret final
}
