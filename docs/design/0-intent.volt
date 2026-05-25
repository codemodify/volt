
// primitives - CAN fit in CPU register
var v int8  = 127
var v int16 = 32000
var v int32 = 2000000000
var v int64 = 9000000000
var v int   = 42                    // alias for int64

var v uint8  = 255
var v uint16 = 65000
var v uint32 = 4000000000
var v uint64 = 18000000000
var v uint   = 99                   // alias for uint64

var v byte   = 7                    // alias for uint8
var v bool   = false

// composites - CAN'T fit in CPU register, needs memory backing
// convention: new(SIZE) {INIT_VALS}, SIZE + INIT_VALS are optional
type Counter struct {
    value int
}

var v string = "hello, volt"
var v Counter = new {}
var v map[string]int = new {}
var v []int = new {}

// concurrency
var v chan int = new()              // default is 1
var v mutex Counter = new {}        // can't have a size
var v rwmutex Counter = new {}      // can't have a size
var v atomic int = new {}           // can't have a size
var v waitgroup = new()             // counter as initial value, Wait() until 0
var v once = new()                  // can't have a size, run init exactly once across threads/go-routines

// |                  | mutex / rwmutex                            | atomic                                 |
// |------------------|--------------------------------------------|----------------------------------------|
// | mechanism        | blocking — futex, sleep/wake, kernel under | lock-free — single CPU instruction,    |
// |                  | contention                                 | no kernel, never blocks                |
// | cost uncontested | ~10ns + memory ops                         | ~1ns, single instruction               |
// | cost contended   | µs (kernel wakeup)                         | nanoseconds (CPU may spin once on CAS) |
// | shape            | acquire → critical section → release       | one op fires-and-completes             |
// | critical section | yes                                        | no — there is no "section"             |
