// atomic primitive smoke test — two threads each Add(1) 1000 times.
// Final value via Load() should equal 2000. Exit 42 = success.
//
// Tests:
//   - var x atomic int = new{} (zero-init) or new{5} (initial value)
//   - passing atomic handle to a goroutine (reference-typed)
//   - a.Add(1) under contention
//   - a.Load() returns the final value

package main

fun bumper(a atomic int, done chan int) {
    var i int = 0
    for i < 1000 {
        a.Add(1)
        i = i + 1
    }
    write(done, 1)
}

fun main() int {
    var a atomic int = new{}
    var done chan int = new(2) chan int
    run bumper(a, done)
    run bumper(a, done)
    read(done)
    read(done)
    var final int = a.Load()
    if final == 2000 {
        ret 42
    }
    ret final
}
