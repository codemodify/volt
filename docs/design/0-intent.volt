// volt:noformat — this file is the canonical spec; alignment is hand-tuned.
//                  `volt fmt -w` will refuse to overwrite; use --force only
//                  when you intentionally want to reformat (you almost never do).

// primitives - CAN fit in CPU register
var v int8  = 127
var v int16 = 32000
var v int32 = 2000000000
var v int64 = 9000000000
var v int   = 42                        // alias for int64

var v uint8  = 255
var v uint16 = 65000
var v uint32 = 4000000000
var v uint64 = 18000000000
var v uint   = 99                       // alias for uint64

var v byte   = 7                        // alias for uint8
var v bool   = false

// composites - no allocation formula
var v string = "hello, volt"            // immutable, owned bytes; literal syntax; clone() for a fresh copy

// composites - needs allocation formula: new(SIZE) {INIT_VALS}; both optional
type Counter struct {
    value int
}

var v Counter = new {}
var v map[string]int = new {}
var v []int = new {}

// concurrency
var v chan int = new()                  // read + write, cap=0 (blocks until data); new(N) for buffered
var v mutex Counter = new {}            // can't have a size, thus no () after "new"
var v rwmutex Counter = new {}          // can't have a size, thus no () after "new"
var v atomic int = new {}               // can't have a size, thus no () after "new"
var v waitgroup = new()                 // counter starts at 0; new(N) pre-loads counter=N; Wait() blocks until 0
var v once = new()                      // can't have a size, runs exactly once across threads
var v condvar = new()                   // wait/signal/broadcast pair: c.Wait(m), c.Signal(), c.Broadcast()

// borrows - shared (read) vs exclusive (read+write)
// `&T` is a shared borrow. Multiple `&T` of the same source coexist (parallel readers).
//   Mutating the source while a `&T` is held is REJECTED — the source is frozen.
// `&mut T` is an exclusive borrow. Single `&mut T` blocks all other borrows.
//   `*b = v` requires `&mut T`; `*b` reads through either form.
//   Closures may capture borrows; they cannot escape the borrowed scope.
fun read(p &int) int { ret p }          // sees source value (read-only access)
fun bump(p &mut int) { *p = *p + 1 }   // exclusive write through the borrow

// borrows - lifecycle is block-scoped; multiple shared OK in same block
var x int = 5
{
    var b1 &int = &x                     // shared borrow
    var b2 &int = &x                     // ALSO shared OK
    var sum int = *b1 + *b2              // 10
}                                         // both released at `}`; x is now writable again

// runtime stdlib — observability + allocator control
//   runtime.Compact()              — walk + merge adjacent free blocks
//   runtime.HeapBytes()            — total mmap'd bytes
//   runtime.NumSizeClasses()       — allocator size-class count
//   runtime.FreelistCount(sc)      — free blocks per class
//   runtime.SetArenaChunkSize(n)   — per-chunk mmap size (default 1 MiB)
//   runtime.ThreadCount()          — # threads registered with race detector
//   runtime.RaceViolations()       — cumulative race count (0 without -race)
//   runtime.ResetRaceViolations()  — zero the counter for per-subtest accounting

// concurrency usage - run - spawns a new OS thread; returns immediately
fun greet(id int) {}                    // any function is runnable
run greet(42)                           // launches a real OS thread

// concurrency usage - chan (thread-safe FIFO queue; push on one end, pop on the other)
var ch chan int = new()
write(ch, 42)                           // send, blocks until a reader pairs (cap=0) or buffer has space
v, ok := read(ch)                       // recv, blocks until data is available; ok=false once closed and drained
close(ch)                               // signal "no more sends"

// concurrency usage - chan direction (per-handle narrowing on function params)
fun producer(out chan write int) { write(out, 1); close(out) }   // write + close only, compiler error on read
fun consumer(in  chan read  int) { v, _ := read(in); _ = v }     // read only, compiler error on write/close

// concurrency usage - chan multiplicity contracts (orthogonal to buffer size; shown unbuffered here)
var ch1 chan11 int = new()              // contract: 1 reader - 1 writer
var ch2 chan1N int = new()              // contract: 1 reader - many writers
var ch3 chanN1 int = new()              // contract: many readers - 1 writer
var ch4 chanNN int = new()              // contract: many readers - many writers

// concurrency usage - chan select - wait on the first-ready channel
var fast chan int = new(1)
var slow chan int = new(1)
select {
case x := read(fast):                   // taken when `fast` has data
case y := read(slow):                   // taken when `slow` has data
default:                                // optional: non-blocking poll - runs if no case is ready
}

// concurrency usage - mutex - exclusive guard, auto-release at scope end, no Unlock method removes a whole class of bugs
var m mutex Counter = new {value: 0}
{
    v := m.Lock()                       // acquire - v is the guard
    v.value = v.value + 1               // exclusive write through the guard
}                                       // guard drops here → unlock fires

// concurrency usage - rwmutex T - many readers OR one writer
var r rwmutex Counter = new {value: 0}
{
    v := r.Lock()                       // writer guard - exclusive
    v.value = v.value + 1
}                                       // → unlock
{
    v := r.LockRead()                   // reader guard - shared, read-only
    log.Println("%d", v.value)
}                                       // → unlock_read

// concurrency usage - atomic - lock-free, single CPU instructions
var a atomic int = new {}
a.Add(1)                                // atomic add
var n int = a.Read()                    // atomic load
a.Write(42)                             // atomic store
var ok bool = a.CompSwap(42, 100)       // compare-and-swap (true = success)

// concurrency usage - waitgroup - spawn N workers, wait for all to finish
var wg waitgroup = new()
wg.Add(1)
run worker(wg)                          // worker calls wg.Done() at the end
wg.Wait()                               // blocks until counter == 0

// concurrency usage - once - run exactly once across all threads
var o once = new()
o.Do(fun() {                            // closure runs once; every caller blocks until done
    log.Println("init")
})
