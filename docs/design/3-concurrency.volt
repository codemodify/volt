// volt:noformat — spec file; hand-aligned.
// =====================================================================
// 3-concurrency.volt — `run` and channels
// =====================================================================
// `run f()` launches f on a real OS thread. Channels are typed,
// blocking, reference-typed (passing a `chan T` value gives another
// handle to the same channel), and **unbuffered by default** — `new()`
// allocates cap=0 (rendezvous, same as Go); `new(N)` adds a buffer of N.
//
// Channel direction: `chan read T` permits only `read`; `chan write T`
// permits only `write` and `close`. A plain `chan T` is an unrestricted
// handle (both ops allowed) and narrows implicitly at the call site.
// Many threads can share each direction — "many readers and many
// writers" still applies on the same channel.
//
// Channel multiplicity contracts (compile-time, same runtime).
// Notation: chan<readers><writers>, 1 = exactly one, N = one or more.
//   chan11 T   — One Reader, One Writer
//   chan1N T   — One Reader, Many Writers
//   chanN1 T   — Many Readers, One Writer
//   chanNN T   — Many Readers, Many Writers
// The compiler counts reader / writer endpoints in the declaring scope
// (direct read/write/close, `run f(ch)` direction, send sites) and
// errors if the count violates the contract. `run f(ch)` inside a `for`
// is treated as "many" spawns of that endpoint kind.
//
// Channel operations:
//   write(ch, value)     — send (blocks until paired with a reader on cap=0;
//                          blocks if buffer full on cap>0)
//   read(ch)             — receive one value (blocks if no sender pending)
//   v, ok := read(ch)    — receive-or-closed (ok=false once drained+closed)
//   close(ch)            — signal "no more sends"
//
// Only OWNED `T` values cross channels — peeks (&T) and write/heap pointers (*T) cannot
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

fun producer(out chan write int) {     // write-only endpoint
    for i := 1; i <= 5; i++ {
        write(out, i)                  // blocks until a reader pairs (cap=0)
    }
    close(out)                         // signal "no more sends"
}

fun consumer(in chan read int, done chan write int) {  // read-only on `in`
    var sum int = 0
    for {
        v, ok := read(in)              // receive-or-closed
        if !ok { break }               // ok=false once drained+closed
        sum = sum + v
    }
    write(done, sum)
}

fun producerConsumer() {
    var ch   chan int = new()              // cap=0 — rendezvous (default)
    var done chan int = new(1) chan int    // small buffer so main isn't blocked

    run producer(ch)                       // narrows to `chan write int`
    run consumer(ch, done)                 // narrows to `chan read int` + `chan write int`

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
    for i := 0; i < 1000; i++ {
        a.Add(1)                           // single atomic add
    }
    write(done, 1)
}

fun atomicDemo() {
    var a    atomic int = new {}
    var done chan int   = new(2) chan int

    run atomicBumper(a, done)              // two threads racing the same counter
    run atomicBumper(a, done)
    read(done)
    read(done)

    if a.Read() == 2000 {                  // -> 2000 (no lost updates)
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
    for i := 0; i < 1000; i++ {
        var v int = m.Lock()               // acquire — v is a guard over the int
        v = v + 1                          // write through the guard
    }                                      // guard drops at iteration end → lock released
    write(done, 1)
}

fun mutexDemo() {
    var m    mutex int = new {}
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
    for i := 0; i < 100; i++ {
        var v int = r.Lock()               // writer guard
        v = v + 1                          // exclusive write
    }                                      // guard drops → exclusive lock released
    write(done, 1)
}

fun rwReader(r rwmutex int, done chan int) {
    var sum int = 0
    for i := 0; i < 1000; i++ {
        var v int = r.LockRead()           // reader guard (read-only)
        sum = sum + v
    }                                      // guard drops → read lock released
    write(done, 1)
}

fun rwmutexDemo() {
    var r    rwmutex int = new {}
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

// =====================================================================
// 7. mutex Counter — struct payload (the "worked example" from the .md)
// =====================================================================
// Same shape as the int-payload demo but the protected value is a
// struct. `c.Lock()` binds a guard whose field accesses (`v.value`)
// read and write directly through the mutex's inline storage.

type Counter struct {
    value int
}

fun counterBumper(c mutex Counter, done chan int) {
    for i := 0; i < 1000; i++ {
        var v Counter = c.Lock()       // (1) acquire — v is the guard
        v.value = v.value + 1          //     exclusive write through the guard
    }                                  // (2) v drops at iteration end → unlock fires
    write(done, 1)
}

fun mutexCounterDemo() {
    var c    mutex Counter = new {value: 0}
    var done chan int      = new(2) chan int

    run counterBumper(c, done)
    run counterBumper(c, done)
    read(done)
    read(done)

    var snap Counter = c.Lock()        // (1) acquire at function scope
    if snap.value == 2000 {
        log.Println("mutex Counter ok")
    }
}                                      // (2) snap drops at function end → unlock fires

// =====================================================================
// 8. once — first-touch initialization (closure form, the only form)
// =====================================================================
// `o.Do(fun() { ... })` runs the closure exactly once across all
// callers. Every caller blocks until that single run completes, then
// proceeds. Anything that needs to happen "if I'm the first arriver"
// goes inside the closure — the closure runs only on the first
// arriver.

fun onceWorker(o once, init_count atomic int, wg waitgroup) {
    o.Do(fun() {
        // This body runs on exactly one thread, even though many
        // threads call onceWorker concurrently.
        init_count.Add(1)
    })
    wg.Done()
}

fun onceDoDemo() {
    var o          once       = new()
    var init_count atomic int = new {}
    var wg         waitgroup  = new()

    for i := 0; i < 10; i++ {
        wg.Add(1)
        run onceWorker(o, init_count, wg)
    }
    wg.Wait()

    if init_count.Read() == 1 {
        log.Println("once.Do ok")
    }
}

fun main() {
    producerConsumer()
    selectDemo()
    selectDefault()
    atomicDemo()
    mutexDemo()
    rwmutexDemo()
    mutexCounterDemo()
    onceDoDemo()
    log.Println("concurrency ok")
}
