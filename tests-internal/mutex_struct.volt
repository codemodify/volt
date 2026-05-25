// mutex Counter — two threads mutate a struct payload under the lock.
// Each thread does 1000 field-bumps; final value should be 2000.
// Exit 42 = success.
//
// Tests:
//   - var c mutex Counter = new {value: 0}  (struct-payload init via braces)
//   - var v Counter = c.Lock()             (guard binding)
//   - v.value = v.value + 1                (field write through guard)
//   - guard auto-releases at end of loop iteration (no Unlock call)

package main

type Counter struct {
    value int
}

fun bumper(c mutex Counter, done chan int) {
    for i := 0; i < 1000; i++ {
        var v Counter = c.Lock()
        v.value = v.value + 1
    }
    write(done, 1)
}

fun main() int {
    var c mutex Counter = new {value: 0}
    var done chan int = new(2) chan int
    run bumper(c, done)
    run bumper(c, done)
    read(done)
    read(done)
    var snap Counter = c.Lock()
    if snap.value == 2000 {
        ret 42
    }
    ret 0
}
