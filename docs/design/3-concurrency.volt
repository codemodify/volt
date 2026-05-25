// =====================================================================
// 3-concurrency.volt — `run` and channels
// =====================================================================
// `run f()` launches f on a real OS thread. Channels are typed,
// bounded, blocking, and reference-typed (passing a `chan T` value
// gives another handle to the same channel — both endpoints must
// hold it simultaneously).
//
// Channel operations:
//   write(ch, value)     — send (blocks if buffer full)
//   read(ch)             — receive one value (blocks if empty)
//   v, ok := read(ch)    — receive-or-closed (ok=false once drained+closed)
//   close(ch)            — signal "no more sends"
//
// Only OWNED `T` values cross channels — borrows (&T, *T) cannot
// cross threads.
//
//   volt run docs/design/3-concurrency.volt
//
// For the select grammar and common concurrency patterns (fan-in,
// fan-out, non-blocking poll), see docs/design/3-concurrency.md.

package main

import "log"

// =====================================================================
// 1. Channels — producer / consumer on real threads
// =====================================================================

fun producer(out chan int) {
    var i int = 1
    for i <= 5 {
        write(out, i)                  // send (blocks if buffer is full)
        i = i + 1
    }
    close(out)                         // signal "no more sends"
}

fun consumer(in chan int, done chan int) {
    var sum int = 0
    for {
        v, ok := read(in)              // receive-or-closed
        if !ok { break }               // ok=false once drained+closed
        sum = sum + v
    }
    write(done, sum)
}

fun producerConsumer() {
    var ch   chan int = new(2) chan int    // small buffer forces blocking
    var done chan int = new(1) chan int

    run producer(ch)                       // real OS thread
    run consumer(ch, done)                 // another real OS thread

    var total int = read(done)             // -> 15  (1+2+3+4+5)
    if total == 15 {
        log.Println("producer/consumer ok")
    }
}

// =====================================================================
// 2. select — wait for the first ready channel
// =====================================================================
// `select` blocks until one of its cases is ready, then runs that
// case's body. If multiple are ready, one is picked.

fun selectDemo() {
    var fast chan int = new(1) chan int
    var slow chan int = new(1) chan int

    write(fast, 42)                        // make `fast` ready immediately

    var got int = 0
    select {
    case x := read(fast):                  // wins — `fast` has a value
        got = x
    case y := read(slow):                  // alternative path
        got = y * 100
    }

    if got == 42 {                         // -> 42 (fast won)
        log.Println("select ok")
    }
}

// =====================================================================
// 3. select with default — non-blocking
// =====================================================================
// `default:` makes the select non-blocking — runs immediately if no
// other case is ready.

fun selectDefault() {
    var empty chan int = new(1) chan int   // never written to

    var got int = 0
    select {
    case v := read(empty):
        got = v                            // skipped — channel is empty
    default:
        got = 99                           // runs immediately
    }

    if got == 99 {                         // -> 99 (default ran)
        log.Println("select default ok")
    }
}

// =====================================================================
// 4. atomic — lock-free counter shared across threads
// =====================================================================
// `var x atomic T` mirrors `var ch chan T`: reference-typed handle,
// constructed with `new(initial)`. Methods compile to single CPU
// instructions (no kernel call uncontested).

fun atomicBumper(a atomic int, done chan int) {
    var i int = 0
    for i < 1000 {
        a.Add(1)                           // single atomic add
        i = i + 1
    }
    write(done, 1)
}

fun atomicDemo() {
    var a    atomic int = new{}
    var done chan int   = new(2) chan int

    run atomicBumper(a, done)              // two threads racing the same counter
    run atomicBumper(a, done)
    read(done)
    read(done)

    if a.Load() == 2000 {                  // -> 2000 (no lost updates)
        log.Println("atomic ok")
    }
}

// =====================================================================
// 5. mutex — exclusive access via a scope-bound guard
// =====================================================================
// `Lock()` blocks until the lock is acquired and binds a guard to the
// declared variable. Reads and writes through the guard go straight to
// the mutex's storage. The lock releases automatically when the guard
// goes out of scope — there is no Unlock method.

fun mutexBumper(m mutex int, done chan int) {
    var i int = 0
    for i < 1000 {
        var v int = m.Lock()               // acquire — v is a guard over the int
        v = v + 1                          // write through the guard
        i = i + 1
    }                                      // guard drops at iteration end → lock released
    write(done, 1)
}

fun mutexDemo() {
    var m    mutex int = new{}
    var done chan int  = new(2) chan int

    run mutexBumper(m, done)
    run mutexBumper(m, done)
    read(done)
    read(done)

    var final int = m.Lock()
    if final == 2000 {                     // -> 2000
        log.Println("mutex ok")
    }
}

// =====================================================================
// 6. rwmutex — many readers OR one writer (guard-with-Drop)
// =====================================================================
// `Lock()` binds a writer guard — exclusive, field writes allowed.
// `LockRead()` binds a reader guard — shared, fields are read-only
// (writes through the guard fail at compile time). Both auto-release
// at scope end, same as mutex.

fun rwWriter(r rwmutex int, done chan int) {
    var i int = 0
    for i < 100 {
        var v int = r.Lock()               // writer guard
        v = v + 1                          // exclusive write
        i = i + 1
    }                                      // guard drops → exclusive lock released
    write(done, 1)
}

fun rwReader(r rwmutex int, done chan int) {
    var i int = 0
    var sum int = 0
    for i < 1000 {
        var v int = r.LockRead()           // reader guard (read-only)
        sum = sum + v
        i = i + 1
    }                                      // guard drops → read lock released
    write(done, 1)
}

fun rwmutexDemo() {
    var r    rwmutex int = new{}
    var done chan int    = new(3) chan int

    run rwWriter(r, done)
    run rwReader(r, done)
    run rwReader(r, done)
    read(done)
    read(done)
    read(done)

    var final int = r.LockRead()
    if final == 100 {                      // -> 100 (writer ran 100 increments)
        log.Println("rwmutex ok")
    }
}

fun main() {
    producerConsumer()
    selectDemo()
    selectDefault()
    atomicDemo()
    mutexDemo()
    rwmutexDemo()
    log.Println("concurrency ok")
}
