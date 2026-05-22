// =====================================================================
// volt language tour
// =====================================================================
// Design as of 2026-05-21. Nothing here compiles yet — the compiler
// doesn't exist. Stdlib APIs shown (log, time, etc.) are illustrative;
// their exact shape is TBD.
//
// Surface syntax : Go-flavored (var, type, def, channels, run, select).
// Memory model   : ownership + borrow checker, no GC.
// Concurrency    : goroutine-style scheduler, cooperative preemption.
// Target         : 64-bit only (amd64 + arm64), Linux only for v1,
//                  static binary, no libc, no dynamic linking.
// Ruled out      : generics, macros, GC, dynamic linking, libc,
//                  automatic destructors, optionals (?T), nil-pointers,
//                  mutable aliasing, FFI in v1.

package main

import (
    "log"
    "time"
)

// =====================================================================
// 1. Primitive types
// =====================================================================
// Fixed-width integers and floats. Aliases for ergonomics:
//   int   == int64   (one machine word)
//   uint  == uint64
//   float == float64
//   byte  == uint8
// `any` is an alias for `interface{}`. `void` exists only inside
// privileged runtime/syscall packages (raw memory pointer); user code
// never writes `void`.

fun primitives() {
    var a int8        // signed, 1 byte
    var b int         // == int64, 8 bytes (one machine word)
    var c uint64      // unsigned, 8 bytes
    var d float       // == float64, IEEE 754 double
    var e bool   = false
    var f byte   = 0  // == uint8

    var g string = "hello"               // distinct, immutable, UTF-8, []byte underneath
    var h []int  = []int{1, 2, 3}        // slice; owns backing storage
    var i map[string]int = map[string]int{"a": 1, "b": 2}
}

// =====================================================================
// 2. The memory model — three forms
// =====================================================================
//
//   T    — I own this. I free it at scope end.
//   *T   — Borrowed read/write. Exactly one *T at a time. No &T may exist
//          alongside. Never nil.
//   &T   — Borrowed read-only. Many &T may coexist. No *T may exist
//          alongside. Never nil.
//
// Lifetimes are FULLY INFERRED — no `'a`-style syntax anywhere.
//
// Call sites use BARE NAMES — no `&` or `*` operator at calls. The
// compiler picks move / &T / *T from the receiver's parameter type.
// Tradeoff: move-vs-borrow is invisible at the call site; the LSP
// surfaces it on hover.

type Counter struct {
    value int
}

fun readCounter(c &Counter) int {
    ret c.value
    // c.value = 0   // compile error: cannot write through &T
}

fun bumpCounter(c *Counter) {
    c.value = c.value + 1
}

fun ownershipDemo() {
    var c Counter = Counter{value: 0}

    var n int = readCounter(c)   // bare `c` → compiler takes &Counter
    bumpCounter(c)               // bare `c` → compiler takes *Counter

    var x int = readCounter(c)   // multiple &Counter at once: fine
    var y int = readCounter(c)

    // bumpCounter(c)             // compile error: would conflict with x,y
}

// =====================================================================
// 3. Heap allocation — the unified `new` keyword
// =====================================================================
// `new` is the ONE allocation primitive. There is no `make`. Three forms:
//
//   new(args...)       — parameterized constructor (sized slice/channel, etc.)
//   new()              — default / zero-state construct
//   new{fields...}     — struct/literal field initialization
//
// THE TYPE IS ALWAYS INFERRED FROM CONTEXT (LHS variable, return type,
// function parameter). You don't repeat the type inside `new` — the
// left-hand side already says what it is; `new(...)` just says
// "allocate that". If context is ambiguous, the long form
// `new T(args)` is available as an explicit fallback.
//
// In every case, `new` returns OWNED `T` (heap-allocated). The result
// participates in the normal ownership rules.

type BigBuffer struct {
    bytes [4096]byte
}

fun newDemo() {
    var s BigBuffer = new()              // struct, default-constructed
    var c Counter   = new{value: 5}      // struct, with named fields
    var b []byte    = new(4096)          // slice of length 4096
    var ch chan int = new(256)           // buffered channel, cap 256
    var u chan int  = new()              // unbuffered channel
    var m map[string]int = new()         // empty map
    var n map[string]int = new(64)       // map with capacity hint
}

// =====================================================================
// 4. No optionals — maybe-absent uses multi-return
// =====================================================================
// No `?T`, no nil pointers. To express "the answer might be absent",
// return (T, bool) or (T, error). Cost: every type needs a sensible
// zero value for the "absent" return slot.

type User struct {
    id int
}

fun findUser(id int) (User, bool) {
    if id == 0 {
        ret User{}, false
    }
    ret User{id: id}, true
}

fun maybeAbsentDemo() {
    var u User
    var ok bool
    u, ok = findUser(42)
    if ok {
        log.Println(u.id)
    }
}

// =====================================================================
// 5. Move semantics
// =====================================================================

type Buffer struct {
    data []byte
}

fun consumes(b Buffer) {
    // b is now owned by `consumes`. Caller's variable is invalidated.
}

fun moveDemo() {
    var b Buffer = Buffer{data: []byte{1, 2, 3}}

    consumes(b)
    // Using b here would be a compile error.

    // To keep ownership in this scope, call a function whose parameter
    // is &Buffer or *Buffer — bare `b` then becomes a borrow.
}

// =====================================================================
// 6. Error handling — multi-return (T, error)
// =====================================================================
// `error` is a built-in structural interface. Interfaces (unlike *T
// and &T) CAN be nil — that's the language's only nullable type.
// `*T` and `&T` are non-nullable by construction.

type File struct {
    handle int
}

fun openFile(path string) (File, error) {
    // direct syscall (no libc) — illustrative
    ret File{}, nil
}

fun errorDemo() {
    var f File
    var err error
    f, err = openFile("data.txt")
    if err != nil {
        ret
    }
    def f.Close()
    // ... use f ...
}

// =====================================================================
// 7. Structural interfaces
// =====================================================================
// Any type with matching methods satisfies the interface.
// No `impl` keyword, no nominal typing (like Go).

type Reader interface {
    Read(buf *[]byte) (int, error)
}

type Closer interface {
    Close() error
}

// File satisfies both interfaces simply by having matching methods.

fun (f *File) Read(buf *[]byte) (int, error) {
    ret 0, nil
}

fun (f *File) Close() error {
    ret nil
}

// Method receivers follow the same three-form rule:
//   fun (f File)  m()   — method takes ownership (consumes f; rare)
//   fun (f &File) m()   — method takes a shared borrow
//   fun (f *File) m()   — method takes a unique mutable borrow

// =====================================================================
// 8. Concurrency — goroutines, bounded channels, select
// =====================================================================
// `run f()` launches a goroutine. Channels are typed and BOUNDED.
// Only OWNED `T` values cross channels; borrows (&T, *T) cannot cross
// goroutines. Race-free by construction.
//
// Preemption is COOPERATIVE — goroutines yield at function calls,
// channel ops, and `new`. Tight pure-compute loops should call
// runtime.gosched() periodically.
//
// Channels themselves are a built-in reference-typed primitive: copying
// a `chan T` value gives another handle to the same channel. (This
// exemption from move semantics is needed because both sides of a
// channel must hold it simultaneously.) Maps and slices behave similarly.

fun worker(in chan int, out chan int) {
    for {
        v, ok := <-in
        if !ok { ret }
        out <- v * 2
    }
}

fun concurrencyDemo() {
    var jobs    chan int = new(10)
    var results chan int = new(10)

    run worker(jobs, results)

    jobs <- 1
    jobs <- 2

    select {
    case r := <-results:
        log.Println("got", r)
    case <-time.After(1 * time.Second):
        log.Println("timeout")
    }
}

// =====================================================================
// 9. def — the only user-visible cleanup
// =====================================================================
// No Drop trait, no auto-destructors. The compiler frees MEMORY at
// scope exit; user cleanup (close files, release locks) goes in def.
// Calls execute in LIFO order.

fun defDemo() {
    var f File
    var err error
    f, err = openFile("data.txt")
    if err != nil {
        ret
    }
    def f.Close()
    // ... critical work ...
}

// =====================================================================
// 10. Entry point
// =====================================================================

fun main() {
    primitives()
    ownershipDemo()
    maybeAbsentDemo()
    moveDemo()
    errorDemo()
    concurrencyDemo()
    defDemo()
}
